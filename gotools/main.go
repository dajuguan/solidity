package main

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/go-resty/resty/v2"
)

type (
	RawABIResponse struct {
		Status  *string `json:"status"`
		Message *string `json:"message"`
		Result  *string `json:"result"`
	}

	EnvConfig struct {
		InfuraApiKey string `json:"infura-api-key"`
	}
)

func GetContractRawABI(address string, apiKey string) (*RawABIResponse, error) {
	client := resty.New()
	rawABIResponse := &RawABIResponse{}
	resp, err := client.R().
		SetQueryParams(map[string]string{
			"module":  "contract",
			"action":  "getabi",
			"address": address,
			"apikey":  apiKey,
		}).
		SetResult(rawABIResponse).
		Get("https://api.etherscan.io/api")

	if err != nil {
		return nil, err
	}
	if !resp.IsSuccess() {
		return nil, fmt.Errorf(fmt.Sprintf("Get contract raw abi failed: %s\n", resp))
	}
	if *rawABIResponse.Status != "1" {
		return nil, fmt.Errorf(fmt.Sprintf("Get contract raw abi failed: %s\n", *rawABIResponse.Result))
	}

	return rawABIResponse, nil
}

// refer
// https://github.com/ethereum/web3.py/blob/master/web3/contract.py#L435
func DecodeTransactionInputData(contractABI *abi.ABI, data []byte) {
	methodSigData := data[:4]
	inputsSigData := data[4:]
	method, err := contractABI.MethodById(methodSigData)
	if err != nil {
		log.Fatal(err)
	}
	inputsMap := make(map[string]interface{})
	if err := method.Inputs.UnpackIntoMap(inputsMap, inputsSigData); err != nil {
		log.Fatal(err)
	} else {
		fmt.Println(inputsMap)
	}
	fmt.Printf("Method Name: %s\n", method.Name)
	fmt.Printf("Method inputs: %v\n", inputsMap)
}

func GetTransactionMessage(tx *types.Transaction) types.Message {
	msg, err := tx.AsMessage(types.LatestSignerForChainID(tx.ChainId()), nil)
	if err != nil {
		log.Fatal(err)
	}
	return msg
}

func ParseTransactionBaseInfo(tx *types.Transaction) {
	fmt.Printf("Hash: %s\n", tx.Hash().Hex())
	fmt.Printf("ChainId: %d\n", tx.ChainId())
	fmt.Printf("Value: %s\n", tx.Value().String())
	fmt.Printf("From: %s\n", GetTransactionMessage(tx).From().Hex())
	fmt.Printf("To: %s\n", tx.To().Hex())
	fmt.Printf("Gas: %d\n", tx.Gas())
	fmt.Printf("Gas Price: %d\n", tx.GasPrice().Uint64())
	fmt.Printf("Nonce: %d\n", tx.Nonce())
	fmt.Printf("Transaction Data in hex: %s\n", hex.EncodeToString(tx.Data()))
}

func DecodeTransactionLogs(receipt *types.Receipt, contractABI *abi.ABI) {
	for _, vLog := range receipt.Logs {
		// topic[0] is the event name
		event, err := contractABI.EventByID(vLog.Topics[0])
		if err != nil {
			log.Fatal(err)
		}
		fmt.Printf("Event Name: %s\n", event.Name)
		// topic[1:] is other indexed params in event
		if len(vLog.Topics) > 1 {
			for i, param := range vLog.Topics[1:] {
				fmt.Printf("Indexed params %d in hex: %s\n", i, param)
				fmt.Printf("Indexed params %d decoded %s\n", i, common.HexToAddress(param.Hex()))
			}
		}
		if len(vLog.Data) > 0 {
			fmt.Printf("Log Data in Hex: %s\n", hex.EncodeToString(vLog.Data))
			outputDataMap := make(map[string]interface{})
			err = contractABI.UnpackIntoMap(outputDataMap, event.Name, vLog.Data)
			if err != nil {
				log.Fatal(err)
			}
			fmt.Printf("Event outputs: %v\n", outputDataMap)
		}
	}
}

func GetContractABI(contractAddress, etherscanAPIKey string) *abi.ABI {
	rawABIResponse, err := GetContractRawABI(contractAddress, etherscanAPIKey)
	if err != nil {
		log.Fatal(err)
	}

	contractABI, err := abi.JSON(strings.NewReader(*rawABIResponse.Result))
	if err != nil {
		log.Fatal(err)
	}
	return &contractABI
}

func GetTransactionReceipt(client *ethclient.Client, txHash common.Hash) *types.Receipt {
	receipt, err := client.TransactionReceipt(context.Background(), txHash)
	if err != nil {
		log.Fatal(err)
	}
	return receipt
}

func main() {
	// get etherscanAPIKEY from https://docs.etherscan.io/getting-started/viewing-api-usage-statistics
	// https://docs.etherscan.io/getting-started/endpoint-urls
	const etherscanAPIKEY = "M3SF4WTDC4NWQIIVNAZDFXBW1SW49QWDNZ"

	var config EnvConfig // Read errors caught by unmarshal
	fileBytes, _ := ioutil.ReadFile("../.env")
	err := json.Unmarshal(fileBytes, &config)
	if err != nil {
		log.Fatal("Error when opening .env: ", err)
	}

	providerUrl := fmt.Sprintf("%s%s", "https://mainnet.infura.io/v3/", config.InfuraApiKey)

	client, err := ethclient.Dial(providerUrl)
	if err != nil {
		log.Fatal("Error dial:", err)
	}
	// https://etherscan.io/tx/0x6fb26649af48dd3c9b50ca9ae2fc532ea95900ffaf8f063a5f5c48b65b5999f3
	txHash := common.HexToHash("0x6fb26649af48dd3c9b50ca9ae2fc532ea95900ffaf8f063a5f5c48b65b5999f3")
	tx, isPending, err := client.TransactionByHash(context.Background(), txHash)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("tx isPending: %t\n", isPending)
	ParseTransactionBaseInfo(tx)
	proxiedContractAddr := "0x4146df64d83acb0dcb0c1a4884a16f090165e122"
	contractABI := GetContractABI(proxiedContractAddr, etherscanAPIKEY)
	DecodeTransactionInputData(contractABI, tx.Data())
	receipt := GetTransactionReceipt(client, txHash)
	DecodeTransactionLogs(receipt, contractABI)
}
