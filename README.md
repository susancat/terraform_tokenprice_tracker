# 📊 Token Tracker - AWS Lambda + Terraform

A serverless crypto price tracker that fetches BTC, ETH, and top-gainer token data daily via CoinGecko API, stores them in DynamoDB, and alerts via SNS on errors.

## ☁️ Stack Used

- AWS Lambda (Python)
- AWS DynamoDB
- AWS CloudWatch Logs & Alarms
- AWS SNS Email Alerts
- AWS EventBridge Scheduler
- Terraform (IaC)

## 💡 Features

- Daily fetch of BTC & ETH prices and volatility
- Logs top gainer token daily
- Writes all data to DynamoDB with timestamp
- Scheduled via EventBridge (cron 9AM Taiwan time)
- Errors trigger SNS Email alerts
- Entire infrastructure deployed with Terraform

## 📁 Directory Structure

...
