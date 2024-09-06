# https://www.quicknode.com/docs/ethereum/eth_getLogs
curl https://docs-demo.quiknode.pro/ \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"method":"eth_getLogs","params":[{"address": "0xdAC17F958D2ee523a2206206994597C13D831ec7"}],"id":1,"jsonrpc":"2.0"}'