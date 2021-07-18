### requester

This script sets up the config requred to request tls certs from the specified cfssl issuing server  
This script uses cfssl and cfssljson packages from Cloudflare's cfssl library  

Designed to be used alongside [issuer](https://github.com/mrityunjaygr8/issuer/)

```
Usage: requester.sh [OPTIONS]

This script sets up the config requred to request tls certs from the specified cfssl issuing server
This script uses cfssl and cfssljson packages from Cloudflare's cfssl library

Options:

--target-dir            The Directory where to install the configs and the cert files. Defaults to "."
--requester-cn          The CN of the requested certificates. Required
--issuer-host           DNS name or the IP address and the port of the hosts where the issuer can be accessed. Defaults to "https://localhost:8888"
--api-pass              The Passowrd for the issuer API. Should be a 16 byte hex string. Can be generated using https://www.browserling.com/tools/random-hex. Required
-h, --help              Show this message and exit

Example:
  requester.sh --target-dir requester --issuer-host "https://issuer.example.com:8888" --api-pass="7be2e3fda569b88b"

In Case tls is used by the issuing server, its tls-cert needs to be copied into this machine
A new Certificate can be rqeusted as follows

  cfssl gencert -config=requester.config.json -hostname="requester.example.com" -profile="default" -tls-remote-ca issuer.pem requester.config.json | cfssljson -bare requester

For more information, please consult the cfssl documentation
```

#### TODO
- [ ] Check if binaries are present
- [ ] Download binaries if required