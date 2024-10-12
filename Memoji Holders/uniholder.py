import requests
from bech32 import bech32_encode, bech32_decode, convertbits
import json

# Replace these with your specific values
RPC_ENDPOINT = "https://rest.unicorn.meme"
CONTRACT_ADDRESS = "unicorn1rn9f6ack3u8t3ed04pfaqpmh5zfp2m2ll4mkty"
DENOM = "udenom"  # Replace with your token's denom

def check_connection():
    print("Checking connection to the blockchain...")
    try:
        # Try to get the latest block
        response = requests.get(f"{RPC_ENDPOINT}/cosmos/base/tendermint/v1beta1/blocks/latest")
        response.raise_for_status()
        block_data = response.json()
        
        # Extract and print some basic information
        block_height = block_data['block']['header']['height']
        block_time = block_data['block']['header']['time']
        print(f"Successfully connected to the blockchain.")
        print(f"Latest block height: {block_height}")
        print(f"Latest block time: {block_time}")
        
        return True
    except requests.exceptions.RequestException as e:
        print(f"Error connecting to the blockchain: {str(e)}")
        return False

def main():
    if not check_connection():
        print("Failed to connect to the blockchain. Please check your RPC_ENDPOINT.")
        return

    print("Starting to fetch token holders...")
    
    try:
        holders = get_token_holders(CONTRACT_ADDRESS)
        
        # Write the results to a JSON file
        with open('token_holders.json', 'w') as f:
            json.dump(holders, f, indent=2)
        
        print(f"Token holder data has been written to token_holders.json")
        
        # Print holders
        for holder in holders:
            print(f"Address: {holder['address']}, Balance: {holder['balance']}")
    except Exception as e:
        print(f"An error occurred: {str(e)}")

def query_contract(contract_address, query):
    """Send a query to a CosmWasm contract."""
    try:
        response = requests.get(f"{RPC_ENDPOINT}/cosmwasm/wasm/v1/contract/{contract_address}/smart/{query}")
        response.raise_for_status()  # Raise an exception for bad status codes
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error querying contract: {str(e)}")
        return None

def get_token_holders(contract_address):
    """Fetch all token holders and their balances."""
    holders = []
    start_after = None
    
    while True:
        query = {
            "all_accounts": {
                "limit": 100,
                "start_after": start_after
            }
        }
        
        result = query_contract(contract_address, query)
        if result is None:
            break
        
        accounts = result.get("accounts", [])
        print(f"Retrieved {len(accounts)} accounts")
        if not accounts:
            break
        
        balances = get_balances(accounts)
        holders.extend([{"address": account, "balance": balance} for account, balance in zip(accounts, balances)])
        
        if len(accounts) < 100:
            break
        
        start_after = accounts[-1]
    
    return holders

def get_balances(addresses):
    """Get balances for multiple addresses in a single request."""
    balances = []
    for address in addresses:
        try:
            response = requests.get(f"{RPC_ENDPOINT}/cosmos/bank/v1beta1/balances/{address}")
            response.raise_for_status()
            balance_data = response.json().get("balances", [])
            balance = next((int(b["amount"]) for b in balance_data if b["denom"] == DENOM), 0)
            balances.append(balance)
        except requests.exceptions.RequestException as e:
            print(f"Error getting balance for {address}: {str(e)}")
            balances.append(0)
    return balances

if __name__ == "__main__":
    main()
