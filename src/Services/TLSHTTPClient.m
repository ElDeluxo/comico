#import "TLSHTTPClient.h"

// mbedTLS Headers
#include <mbedtls/net_sockets.h>
#include <mbedtls/ssl.h>
#include <mbedtls/entropy.h>
#include <mbedtls/ctr_drbg.h>
#include <mbedtls/error.h>
#include <mbedtls/x509_crt.h>
#include <psa/crypto.h>

@interface TLSHTTPClient ()
@property (nonatomic, strong) dispatch_queue_t workQueue;
@end

@implementation TLSHTTPClient

static mbedtls_x509_crt s_ca_chain;
static mbedtls_entropy_context s_entropy;
static mbedtls_ctr_drbg_context s_ctr_drbg;
static BOOL s_initialized = NO;

+ (instancetype)sharedClient {
    static TLSHTTPClient *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TLSHTTPClient alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _workQueue = dispatch_queue_create("com.comico.tlshttpclient.queue", DISPATCH_QUEUE_CONCURRENT);
        [self initializeTLSIfNeeded];
    }
    return self;
}

- (void)initializeTLSIfNeeded {
    static dispatch_once_t initToken;
    dispatch_once(&initToken, ^{
        // 1. Inicializar subsistema de criptografía PSA
        psa_status_t psaStatus = psa_crypto_init();
        if (psaStatus != PSA_SUCCESS) {
            NSLog(@"[ComicoTLS] psa_crypto_init status: %d", (int)psaStatus);
        }
        
        // 2. Inicializar generador de números aleatorios y entropía
        mbedtls_entropy_init(&s_entropy);
        mbedtls_ctr_drbg_init(&s_ctr_drbg);
        mbedtls_x509_crt_init(&s_ca_chain);
        
        const char *pers = "comico_mbedtls13_client";
        int ret = mbedtls_ctr_drbg_seed(&s_ctr_drbg, mbedtls_entropy_func, &s_entropy,
                                        (const unsigned char *)pers, strlen(pers));
        if (ret != 0) {
            NSLog(@"[ComicoTLS] mbedtls_ctr_drbg_seed fallo: -0x%04X", -ret);
        }
        
        // 3. Cargar cacert.pem del bundle de la app
        NSString *cacertPath = [[NSBundle mainBundle] pathForResource:@"cacert" ofType:@"pem"];
        if (!cacertPath) {
            // Fallback: buscar en el directorio del ejecutable
            NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
            NSString *directPath = [bundlePath stringByAppendingPathComponent:@"cacert.pem"];
            if ([[NSFileManager defaultManager] fileExistsAtPath:directPath]) {
                cacertPath = directPath;
            }
        }
        
        if (cacertPath) {
            ret = mbedtls_x509_crt_parse_file(&s_ca_chain, [cacertPath UTF8String]);
            if (ret < 0) {
                NSLog(@"[ComicoTLS] Error cargando cacert.pem: -0x%04X", -ret);
            } else {
                NSLog(@"[ComicoTLS] Certificados raíz cargados: %d", ret);
            }
        } else {
            NSLog(@"[ComicoTLS] AVISO: cacert.pem no encontrado en el paquete.");
        }
        
        s_initialized = YES;
    });
}

#pragma mark - Public Methods

- (void)fetchURL:(NSURL *)url
         headers:(NSDictionary<NSString *, NSString *> *)headers
      completion:(void(^)(NSData *data, NSHTTPURLResponse *response, NSError *error))completion {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    if (headers) {
        for (NSString *key in headers) {
            [req setValue:headers[key] forHTTPHeaderField:key];
        }
    }
    [self performRequest:req completion:completion];
}

- (void)performRequest:(NSURLRequest *)request
            completion:(void(^)(NSData *data, NSHTTPURLResponse *response, NSError *error))completion {
    dispatch_async(self.workQueue, ^{
        [self executeRequest:request redirectCount:0 completion:^(NSData *d, NSHTTPURLResponse *r, NSError *e) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(d, r, e);
                }
            });
        }];
    });
}

#pragma mark - Execution Core (mbedTLS TLS 1.3 / HTTP)

- (void)executeRequest:(NSURLRequest *)request
         redirectCount:(NSInteger)redirectCount
            completion:(void(^)(NSData *data, NSHTTPURLResponse *response, NSError *error))completion {
    
    if (redirectCount > 5) {
        NSError *err = [NSError errorWithDomain:@"com.comico.tls" code:-1001 userInfo:@{NSLocalizedDescriptionKey: @"Demasiadas redirecciones HTTP"}];
        completion(nil, nil, err);
        return;
    }
    
    NSURL *url = request.URL;
    if (!url || !url.host) {
        NSError *err = [NSError errorWithDomain:@"com.comico.tls" code:-1000 userInfo:@{NSLocalizedDescriptionKey: @"URL inválida"}];
        completion(nil, nil, err);
        return;
    }
    
    BOOL isHTTPS = [url.scheme.lowercaseString isEqualToString:@"https"];
    int port = url.port ? url.port.intValue : (isHTTPS ? 443 : 80);
    NSString *portStr = [NSString stringWithFormat:@"%d", port];
    NSString *host = url.host;
    
    // Conexión y socket
    mbedtls_net_context server_fd;
    mbedtls_net_init(&server_fd);
    
    int ret = mbedtls_net_connect(&server_fd, [host UTF8String], [portStr UTF8String], MBEDTLS_NET_PROTO_TCP);
    if (ret != 0) {
        char errBuf[128];
        mbedtls_strerror(ret, errBuf, sizeof(errBuf));
        NSString *errDesc = [NSString stringWithFormat:@"Error conectando a %@:%d (%s)", host, port, errBuf];
        mbedtls_net_free(&server_fd);
        NSError *err = [NSError errorWithDomain:@"com.comico.tls" code:ret userInfo:@{NSLocalizedDescriptionKey: errDesc}];
        completion(nil, nil, err);
        return;
    }
    
    // Estructuras TLS si es HTTPS
    mbedtls_ssl_context ssl;
    mbedtls_ssl_config conf;
    if (isHTTPS) {
        mbedtls_ssl_init(&ssl);
        mbedtls_ssl_config_init(&conf);
        
        ret = mbedtls_ssl_config_defaults(&conf, MBEDTLS_SSL_IS_CLIENT,
                                          MBEDTLS_SSL_TRANSPORT_STREAM,
                                          MBEDTLS_SSL_PRESET_DEFAULT);
        if (ret != 0) {
            mbedtls_net_free(&server_fd);
            mbedtls_ssl_free(&ssl);
            mbedtls_ssl_config_free(&conf);
            NSError *err = [NSError errorWithDomain:@"com.comico.tls" code:ret userInfo:@{NSLocalizedDescriptionKey: @"Fallo configuración SSL"}];
            completion(nil, nil, err);
            return;
        }
        
        mbedtls_ssl_conf_rng(&conf, mbedtls_ctr_drbg_random, &s_ctr_drbg);
        mbedtls_ssl_conf_ca_chain(&conf, &s_ca_chain, NULL);
        
        // Authmode opcional para máxima compatibilidad con CDNs y saltar fechas desfasadas en iPads viejos
        mbedtls_ssl_conf_authmode(&conf, MBEDTLS_SSL_VERIFY_OPTIONAL);
        
        // Server Name Indication (SNI) obligatorio para Cloudflare / MangaDex
        mbedtls_ssl_set_hostname(&ssl, [host UTF8String]);
        
        ret = mbedtls_ssl_setup(&ssl, &conf);
        if (ret != 0) {
            mbedtls_net_free(&server_fd);
            mbedtls_ssl_free(&ssl);
            mbedtls_ssl_config_free(&conf);
            NSError *err = [NSError errorWithDomain:@"com.comico.tls" code:ret userInfo:@{NSLocalizedDescriptionKey: @"Fallo en setup SSL"}];
            completion(nil, nil, err);
            return;
        }
        
        mbedtls_ssl_set_bio(&ssl, &server_fd, mbedtls_net_send, mbedtls_net_recv, NULL);
        
        // Ejecutar Handshake TLS 1.3
        while ((ret = mbedtls_ssl_handshake(&ssl)) != 0) {
            if (ret != MBEDTLS_ERR_SSL_WANT_READ && ret != MBEDTLS_ERR_SSL_WANT_WRITE) {
                char errBuf[128];
                mbedtls_strerror(ret, errBuf, sizeof(errBuf));
                NSString *errDesc = [NSString stringWithFormat:@"Fallo en Handshake TLS 1.3 con %@ (%s)", host, errBuf];
                mbedtls_net_free(&server_fd);
                mbedtls_ssl_free(&ssl);
                mbedtls_ssl_config_free(&conf);
                NSError *err = [NSError errorWithDomain:@"com.comico.tls" code:ret userInfo:@{NSLocalizedDescriptionKey: errDesc}];
                completion(nil, nil, err);
                return;
            }
        }
    }
    
    // Construir petición HTTP/1.1
    NSString *path = url.path;
    if (!path || path.length == 0) path = @"/";
    if (url.query) {
        path = [NSString stringWithFormat:@"%@?%@", path, url.query];
    }
    
    NSString *method = request.HTTPMethod ?: @"GET";
    NSMutableString *rawReq = [NSMutableString stringWithFormat:@"%@ %@ HTTP/1.1\r\n", method, path];
    [rawReq appendFormat:@"Host: %@\r\n", host];
    [rawReq appendString:@"User-Agent: Comico/1.0 (iOS 9.0; iPad; +https://github.com/ElDeluxo/comico)\r\n"];
    [rawReq appendString:@"Accept: */*\r\n"];
    [rawReq appendString:@"Connection: close\r\n"];
    
    // Cabeceras personalizadas del request
    NSDictionary *allHeaders = request.allHTTPHeaderFields;
    for (NSString *hKey in allHeaders) {
        if (![hKey isEqualToString:@"Host"] && ![hKey isEqualToString:@"Connection"] && ![hKey isEqualToString:@"User-Agent"]) {
            [rawReq appendFormat:@"%@: %@\r\n", hKey, allHeaders[hKey]];
        }
    }
    
    if (request.HTTPBody) {
        [rawReq appendFormat:@"Content-Length: %lu\r\n", (unsigned long)request.HTTPBody.length];
    }
    [rawReq appendString:@"\r\n"];
    
    NSMutableData *sendBuffer = [NSMutableData dataWithData:[rawReq dataUsingEncoding:NSUTF8StringEncoding]];
    if (request.HTTPBody) {
        [sendBuffer appendData:request.HTTPBody];
    }
    
    // Enviar datos
    const unsigned char *sendBytes = (const unsigned char *)sendBuffer.bytes;
    size_t sendLen = sendBuffer.length;
    size_t written = 0;
    while (written < sendLen) {
        if (isHTTPS) {
            ret = mbedtls_ssl_write(&ssl, sendBytes + written, sendLen - written);
        } else {
            ret = mbedtls_net_send(&server_fd, sendBytes + written, sendLen - written);
        }
        if (ret <= 0) {
            if (ret == MBEDTLS_ERR_SSL_WANT_READ || ret == MBEDTLS_ERR_SSL_WANT_WRITE) continue;
            break;
        }
        written += ret;
    }
    
    // Leer respuesta completa
    NSMutableData *responseRaw = [NSMutableData data];
    unsigned char readBuf[4096];
    while (YES) {
        if (isHTTPS) {
            ret = mbedtls_ssl_read(&ssl, readBuf, sizeof(readBuf));
        } else {
            ret = mbedtls_net_recv(&server_fd, readBuf, sizeof(readBuf));
        }
        
        if (ret > 0) {
            [responseRaw appendBytes:readBuf length:ret];
        } else if (ret == 0 || ret == MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY) {
            break; // Servidor cerró conexión limpia
        } else if (ret == MBEDTLS_ERR_SSL_WANT_READ || ret == MBEDTLS_ERR_SSL_WANT_WRITE) {
            continue;
        } else {
            break; // Error o fin
        }
    }
    
    // Limpieza de mbedTLS
    if (isHTTPS) {
        mbedtls_ssl_close_notify(&ssl);
        mbedtls_ssl_free(&ssl);
        mbedtls_ssl_config_free(&conf);
    }
    mbedtls_net_free(&server_fd);
    
    if (responseRaw.length == 0) {
        NSError *err = [NSError errorWithDomain:@"com.comico.tls" code:-1002 userInfo:@{NSLocalizedDescriptionKey: @"Respuesta vacía del servidor"}];
        completion(nil, nil, err);
        return;
    }
    
    // Separar cabeceras y cuerpo
    NSData *delimiter = [@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
    NSRange delimRange = [responseRaw rangeOfData:delimiter options:0 range:NSMakeRange(0, responseRaw.length)];
    if (delimRange.location == NSNotFound) {
        // Intentar con \n\n
        delimiter = [@"\n\n" dataUsingEncoding:NSUTF8StringEncoding];
        delimRange = [responseRaw rangeOfData:delimiter options:0 range:NSMakeRange(0, responseRaw.length)];
    }
    
    if (delimRange.location == NSNotFound) {
        NSError *err = [NSError errorWithDomain:@"com.comico.tls" code:-1003 userInfo:@{NSLocalizedDescriptionKey: @"Respuesta HTTP malformada"}];
        completion(nil, nil, err);
        return;
    }
    
    NSData *headerData = [responseRaw subdataWithRange:NSMakeRange(0, delimRange.location)];
    NSData *bodyData = [responseRaw subdataWithRange:NSMakeRange(delimRange.location + delimRange.length, responseRaw.length - (delimRange.location + delimRange.length))];
    
    NSString *headerString = [[NSString alloc] initWithData:headerData encoding:NSUTF8StringEncoding] ?: [[NSString alloc] initWithData:headerData encoding:NSISOLatin1StringEncoding];
    NSArray *lines = [headerString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    NSInteger statusCode = 200;
    NSMutableDictionary *respHeaders = [NSMutableDictionary dictionary];
    
    for (NSInteger i = 0; i < lines.count; i++) {
        NSString *line = [lines[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (line.length == 0) continue;
        
        if (i == 0) {
            // "HTTP/1.1 200 OK"
            NSArray *parts = [line componentsSeparatedByString:@" "];
            if (parts.count >= 2) {
                statusCode = [parts[1] integerValue];
            }
        } else {
            NSRange colon = [line rangeOfString:@":"];
            if (colon.location != NSNotFound) {
                NSString *hName = [[line substringToIndex:colon.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSString *hVal = [[line substringFromIndex:colon.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                respHeaders[hName] = hVal;
            }
        }
    }
    
    // Desempaquetar chunked transfer encoding si es necesario
    NSString *te = respHeaders[@"Transfer-Encoding"] ?: respHeaders[@"transfer-encoding"];
    if (te && [te.lowercaseString containsString:@"chunked"]) {
        bodyData = [self decodeChunkedData:bodyData];
    }
    
    // Manejar redirecciones automáticas (301, 302, 307, 308)
    if (statusCode >= 301 && statusCode <= 308) {
        NSString *loc = respHeaders[@"Location"] ?: respHeaders[@"location"];
        if (loc) {
            NSURL *redirURL = [NSURL URLWithString:loc relativeToURL:url].absoluteURL;
            if (redirURL) {
                NSMutableURLRequest *redirReq = [request mutableCopy];
                redirReq.URL = redirURL;
                [self executeRequest:redirReq redirectCount:redirectCount + 1 completion:completion];
                return;
            }
        }
    }
    
    NSHTTPURLResponse *httpResp = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:statusCode HTTPVersion:@"HTTP/1.1" headerFields:respHeaders];
    completion(bodyData, httpResp, nil);
}

#pragma mark - Chunked Transfer Decoding Helper

- (NSData *)decodeChunkedData:(NSData *)chunkedData {
    NSMutableData *uncompressed = [NSMutableData data];
    const uint8_t *bytes = (const uint8_t *)chunkedData.bytes;
    NSUInteger totalLen = chunkedData.length;
    NSUInteger cursor = 0;
    
    while (cursor < totalLen) {
        // Encontrar fin de línea de tamaño de chunk
        NSUInteger lineEnd = cursor;
        while (lineEnd < totalLen && bytes[lineEnd] != '\n') {
            lineEnd++;
        }
        if (lineEnd >= totalLen) break;
        
        NSData *lineData = [chunkedData subdataWithRange:NSMakeRange(cursor, lineEnd - cursor)];
        NSString *lineStr = [[[NSString alloc] initWithData:lineData encoding:NSASCIIStringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        unsigned int chunkSize = 0;
        NSScanner *scanner = [NSScanner scannerWithString:lineStr];
        [scanner scanHexInt:&chunkSize];
        
        cursor = lineEnd + 1; // saltar \n
        
        if (chunkSize == 0) break; // Fin de chunks
        
        if (cursor + chunkSize <= totalLen) {
            [uncompressed appendBytes:bytes + cursor length:chunkSize];
            cursor += chunkSize;
            // Saltar \r\n que sigue al chunk
            if (cursor < totalLen && bytes[cursor] == '\r') cursor++;
            if (cursor < totalLen && bytes[cursor] == '\n') cursor++;
        } else {
            // Datos truncados, añadir lo que quede
            [uncompressed appendBytes:bytes + cursor length:totalLen - cursor];
            break;
        }
    }
    
    return uncompressed.length > 0 ? uncompressed : chunkedData;
}

@end
