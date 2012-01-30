rem echo off
rem
rem Create Certificate Authority: ca1
rem ('password' is used for the CA password.)
rem
c:\OpenSSL-Win32\bin\openssl req -new -x509 -days 9999 -config ca1.cnf -keyout ca1-key.pem -out ca1-cert.pem

rem
rem Create Certificate Authority: ca2
rem ('password' is used for the CA password.)
rem
c:\OpenSSL-Win32\bin\openssl req -new -x509 -days 9999 -config ca2.cnf -keyout ca2-key.pem -out ca2-cert.pem
rem echo '01' > ca2-serial
touch ca2-database.txt


rem 
rem agent1 is signed by ca1.
rem
c:\OpenSSL-Win32\bin\openssl genrsa -out agent1-key.pem
c:\OpenSSL-Win32\bin\openssl req -new -config agent1.cnf -key agent1-key.pem -out agent1-csr.pem
c:\OpenSSL-Win32\bin\openssl x509 -req -days 9999 -passin "pass:password" -in agent1-csr.pem -CA ca1-cert.pem -CAkey ca1-key.pem -CAcreateserial -out agent1-cert.pem

c:\OpenSSL-Win32\bin\openssl verify -CAfile ca1-cert.pem agent1-cert.pem

rem
rem agent2 has a self signed cert
rem
rem Generate new private key
c:\OpenSSL-Win32\bin\openssl genrsa -out agent2-key.pem

rem Create a Certificate Signing Request for the key
c:\OpenSSL-Win32\bin\openssl req -new -config agent2.cnf -key agent2-key.pem -out agent2-csr.pem

rem Create a Certificate for the agent.
c:\OpenSSL-Win32\bin\openssl x509 -req -days 9999 -in agent2-csr.pem -signkey agent2-key.pem -out agent2-cert.pem

c:\OpenSSL-Win32\bin\openssl verify -CAfile agent2-cert.pem agent2-cert.pem

rem
rem agent3 is signed by ca2.
rem

c:\OpenSSL-Win32\bin\openssl genrsa -out agent3-key.pem

c:\OpenSSL-Win32\bin\openssl req -new -config agent3.cnf -key agent3-key.pem -out agent3-csr.pem


c:\OpenSSL-Win32\bin\openssl x509 -req -days 9999 -passin "pass:password" -in agent3-csr.pem -CA ca2-cert.pem -CAkey ca2-key.pem -CAcreateserial -out agent3-cert.pem


c:\OpenSSL-Win32\bin\openssl verify -CAfile ca2-cert.pem agent3-cert.pem


rem
rem agent4 is signed by ca2 (client cert)
rem

c:\OpenSSL-Win32\bin\openssl genrsa -out agent4-key.pem

c:\OpenSSL-Win32\bin\openssl req -new -config agent4.cnf -key agent4-key.pem -out agent4-csr.pem

c:\OpenSSL-Win32\bin\openssl x509 -req -days 9999 -passin "pass:password" -in agent4-csr.pem -CA ca2-cert.pem -CAkey ca2-key.pem -CAcreateserial -extfile agent4.cnf -extensions ext_key_usage -out agent4-cert.pem

c:\OpenSSL-Win32\bin\openssl verify -CAfile ca2-cert.pem agent4-cert.pem

rem
rem Make CRL with agent4 being rejected
rem

c:\OpenSSL-Win32\bin\openssl ca -revoke agent4-cert.pem -keyfile ca2-key.pem -passin "pass:password" -cert ca2-cert.pem -config ca2.cnf
c:\OpenSSL-Win32\bin\openssl ca -keyfile ca2-key.pem -passin "pass:password" -cert ca2-cert.pem -config ca2.cnf -gencrl -out ca2-crl.pem

rem del *.pem *.srl ca2-database.txt* ca2-serial
