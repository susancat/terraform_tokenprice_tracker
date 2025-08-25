import json
import urllib.request
import boto3
from datetime import datetime
from decimal import Decimal

def lambda_handler(event, context):
    # CoinGecko API URLs
    base_url = 'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&ids='
    btc_eth_url = base_url + 'bitcoin,ethereum'
    top_gainers_url = base_url + '&order=percent_change_24h_desc&per_page=1&page=1'

    # Get BTC and ETH data
    with urllib.request.urlopen(btc_eth_url) as response:
        coins = json.loads(response.read())

    btc_data = next(coin for coin in coins if coin['id'] == 'bitcoin')
    eth_data = next(coin for coin in coins if coin['id'] == 'ethereum')

    # Volatility calculation (high - low) / current price
    btc_volatility = (btc_data['high_24h'] - btc_data['low_24h']) / btc_data['current_price']
    eth_volatility = (eth_data['high_24h'] - eth_data['low_24h']) / eth_data['current_price']

    # Get top gainer
    with urllib.request.urlopen(top_gainers_url) as response:
        top_coin = json.loads(response.read())[0]

    # Timestamp
    timestamp = datetime.utcnow().isoformat()

    # Save BTC and ETH to DynamoDB
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('TokenPriceHistory')

    for symbol, data, vol in [
        ('BTC', btc_data, btc_volatility),
        ('ETH', eth_data, eth_volatility)
    ]:
        table.put_item(Item={
            'symbol': symbol,
            'timestamp': timestamp,
            'price': Decimal(str(data['current_price'])),
            'volatility': Decimal(str(round(vol, 6)))
        })

    # Return result
    result = {
        'timestamp': timestamp,
        'btc_price': btc_data['current_price'],
        'btc_volatility': round(btc_volatility, 4),
        'eth_price': eth_data['current_price'],
        'eth_volatility': round(eth_volatility, 4),
        'top_token_name': top_coin['name'],
        'top_token_price': top_coin['current_price'],
        'top_token_change_pct': round(top_coin['price_change_percentage_24h'], 2)
    }

    return {
        'statusCode': 200,
        'body': json.dumps(result)
    }
