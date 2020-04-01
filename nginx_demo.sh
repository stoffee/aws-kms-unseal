#!/bin/sh
echo "----------------------------------------"; \\
echo "ls /etc/nginx/certs"; \\
ls -ltrFa /etc/nginx/certs/|grep yet; \\
echo "SSL Cert Info" ; \\
sudo openssl x509 -noout -text -in /etc/nginx/certs/yet.crt |grep -E "Validity|Not|Issuer|CA Issuers" ; \\
sleep 120 ; \\
echo "----------------------------------------"; \\
echo "ls /etc/nginx/certs"; \\
ls -ltrFa /etc/nginx/certs/|grep yet; \\
echo "SSL Cert Info" ; \\
sudo openssl x509 -noout -text -in /etc/nginx/certs/yet.crt |grep -E "Validity|Not|Issuer|CA Issuers" ; \\
sleep 120 ; \\
echo "----------------------------------------"; \\
echo "ls /etc/nginx/certs"; \\
ls -ltrFa /etc/nginx/certs/|grep yet; \\
echo "SSL Cert Info" ; \\
sudo openssl x509 -noout -text -in /etc/nginx/certs/yet.crt |grep -E "Validity|Not|Issuer|CA Issuers"; \\
sleep 120 ; \\
echo "----------------------------------------"; \\
echo "ls /etc/nginx/certs"; \\
ls -ltrFa /etc/nginx/certs/|grep yet; \\
echo "SSL Cert Info" ; \\
sudo openssl x509 -noout -text -in /etc/nginx/certs/yet.crt |grep -E "Validity|Not|Issuer|CA Issuers" ; \\
sleep 120 ; \\
echo "----------------------------------------"; \\
echo "ls /etc/nginx/certs"; \\
ls -ltrFa /etc/nginx/certs/|grep yet; \\
echo "SSL Cert Info" ; \\
sudo openssl x509 -noout -text -in /etc/nginx/certs/yet.crt |grep -E "Validity|Not|Issuer|CA Issuers"
