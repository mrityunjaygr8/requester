#!/bin/bash

readonly SCRIPT_NAME="$(basename "$0")"
function ensure_binaries_accessible {
    if ! [ -x "$(command -v cfssl)" ]; then
        log_error "CFSSL is not installed"
        exit 1
    fi

    if ! [ -x "$(command -v cfssljson)" ]; then
        log_error "CFSSLJSON is not installed"
        exit 1
    fi

}

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
    echo "  requester.sh --target-dir requester --issuer-host \"https://issuer.example.com:8888\" --api-pass \"7be2e3fda569b88b\" --requester-cn \"Requester CN\""
    echo
    echo "In Case tls is used by the issuing server, its tls-cert needs to be copied into this machine"
    echo "A new Certificate can be rqeusted as follows"
    echo
    echo "  cfssl gencert -config=requester.config.json -hostname=\"requester.example.com\" -profile=\"default\" -tls-remote-ca issuer.pem requester.config.json | cfssljson -bare requester"
    echo
    echo "For more information, please consult the cfssl documentation"
}

# Taken from: https://github.com/hashicorp/terraform-aws-consul/blob/master/modules/install-consul/install-consul
function log {
  local -r level="$1"
  local -r message="$2"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info {
  local -r message="$1"
  log "INFO" "$message"
}

function log_warn {
  local -r message="$1"
  log "WARN" "$message"
}

function log_error {
  local -r message="$1"
  log "ERROR" "$message"
}

function assert_not_empty {
  local -r arg_name="$1"
  local -r arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log_error "The value for '$arg_name' cannot be empty"
    print_usage
    exit 1
  fi
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

    ensure_binaries_accessible

    assert_not_empty "requester-cn" "$REQUESTER_CN"
    assert_not_empty "api-pass" "$API_PASS"
    assert_not_empty "hostname" "$HOSTNAME"
    assert_not_empty "issuer-pem" "$ISSUER_PEM"

    hex_string_is_valid "$API_PASS"
    PASS_VALID="$?"
    if [ "$PASS_VALID" -ne 0 ]
    then
        log_error "Improper api-pass. Please enter a 16 byte hex string"
        log_error "You can use https://www.browserling.com/tools/random-hex to generate a valid api-pass"
        usage
        exit 1
    fi
    log_info "Creating target directory, \"$TARGET_DIR\", if it does not exist"
    mkdir -p "$TARGET_DIR"
    log_info "Copying the Issuer Pem to \"$TARGET_DIR\""
    cp "$ISSUER_PEM" "$TARGET_DIR"
    cd "$TARGET_DIR"
    log_info "Creating the CSR Files"
    create_csr_files  "$REQUESTER_CN" 
    log_info "Creating the Requester config"
    create_config_file "$ISSUER_HOST" "$API_PASS"
    log_info "Requesting a certificate"
}

main "$@"