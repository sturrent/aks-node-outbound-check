# aks-node-outbound-check
Script to consolidate general outbound checks to validate nodes connectivity

Usage:
```
./outbound-check.sh -h
outbound-check usage: outbound-check [-a|--all] [-d|--dns <FQDN>] [-o|--outbound <FQDN|IP>] [-r|--required-out] [-s|--src] [-h|--help] [--version]

"-a|--all" run all checks
"-d|--dns" check DNS resolution
"-k|--k8s-api" check Kubernetes API connectivity
"-o|--outbound" check outbound connectivity to Internet
"-r|--required-out" check connectivity to required FQDNs
"-s|--src" get public source IP use in outbound
"-h|--help" help info
"--version" print version
```
