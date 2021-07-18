#!/bin/bash

function create_csr_files {
    local readonly REQUESTER_CN="$1"
    cat <<EOL > "./requester.csr.json"
{
    "CN": "$REQUESTER_CN",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "IN",
            "L": "Pune",
            "O": "MGR8",
            "OU": "PKI party",
            "ST": "Maharashtra"
        }
    ]
}
EOL
}

function create_config_file {
    local readonly ISSUER_HOST="$1"
    local readonly API_PASS="$2"
    cat <<EOL > "./requester.config.json"
{
    "signing": {
        "default": {
            "auth_remote": {
                "auth_key": "default",
                "remote": "ca_server"
            }
        }
    },
    "auth_keys": {
        "default": {
            "key": "$API_PASS",
            "type": "standard"
        }
    },
    "remotes": {
        "ca_server": "$ISSUER_HOST"
    }
}
EOL
}

# taken from https://stackoverflow.com/a/7662661
function hex_string_is_valid {
    case $1 in
      ( *[!0-9A-Fa-f]* | "" ) return 1 ;;
      ( * )                
        case ${#1} in
          ( 16 ) return 0 ;;
          ( * )       return 1 ;;
        esac
    esac    
}

function usage {
    echo 
    echo "Usage: requester.sh [OPTIONS]"
    echo 
    echo "This script sets up the config requred to request tls certs from the specified cfssl issuing server"
    echo "This script uses cfssl and cfssljson packages from Cloudflare's cfssl library"
    echo 
    echo "Options:"
    echo 
    echo -e "--target-dir\t\tThe Directory where to install the configs and the cert files. Defaults to \".\""
    echo -e "--requester-cn\t\tThe CN of the requested certificates. Required"
    echo -e "--issuer-host\t\tDNS name or the IP address and the port of the hosts where the issuer can be accessed. Defaults to \"https://localhost:8888\""
    echo -e "--api-pass\t\tThe Passowrd for the issuer API. Should be a 16 byte hex string. Can be generated using https://www.browserling.com/tools/random-hex. Required"
    echo -e "-h, --help\t\tShow this message and exit"
    echo 
    echo "Example:"
    echo "  requester.sh --target-dir requester --issuer-host \"https://issuer.example.com:8888\" --api-pass=\"7be2e3fda569b88b\""
    echo
    echo "In Case tls is used by the issuing server, its tls-cert needs to be copied into this machine"
    echo "A new Certificate can be rqeusted as follows"
    echo
    echo "  cfssl gencert -config=requester.config.json -hostname=\"requester.example.com\" -profile=\"default\" -tls-remote-ca issuer.pem requester.config.json | cfssljson -bare requester"
    echo
    echo "For more information, please consult the cfssl documentation"
}

function main {
    local TARGET_DIR="."
    local REQUESTER_CN=""
    local ISSUER_HOST="https://localhost:8888"
    local API_PASS=""
    while [[ $# -gt 0 ]]; do
        key="$1"

        case $key in
            --target-dir)
            TARGET_DIR="$2"
            shift # past argument
            shift # past value
            ;;
            --requester-cn)
            REQUESTER_CN="$2"
            shift
            shift
            ;;
            --issuer-host)
            ISSUER_HOST="$2"
            shift
            shift
            ;;
            --api-pass)
            API_PASS="$2"
            shift
            shift
            ;;
            -h|--help)
            usage
            exit 0
            ;;
            *)    # unknown option
            echo "Unrecognosed argument: $key"
            exit 1
            ;;
        esac
    done

    if [ -z "$REQUESTER_CN" ]
    then
        echo "The requester-cn cannot be blank"
        usage
        exit 1
    fi
    if [ -z "$API_PASS" ]
    then
        echo "The api-pass cannot be blank"
        usage
        exit 1
    fi

    hex_string_is_valid "$API_PASS"
    PASS_VALID="$?"
    if [ "$PASS_VALID" -ne 0 ]
    then
        echo "Improper api-ass. Please enter a 16 byte hex string"
        echo "You can use https://www.browserling.com/tools/random-hex to generate a valid api-pass"
        usage
        exit 1
    fi
    set -xe
    mkdir -p "$TARGET_DIR"
    cd "$TARGET_DIR"
    create_csr_files  "$REQUESTER_CN" 
    create_config_file "$ISSUER_HOST" "$API_PASS"
}

main "$@"