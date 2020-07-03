# Foundry VTT Terraform

This project aims to simplify the setup of Foundry VTT in the AWS cloud via Terraform.

## EULA

Running services in the AWS cloud incur costs. The recommendations here attempt to stay within the Free Tier of those services.
Operational costs are solely the responsibility of the account administrator. By using this project, you agree that the author
assumes no responsibility for any costs incurred from the use of this project.

## Prerequisites

-   AWS Cloud Account
-   AWS CLI
-   Terraform

## Server Keys

It is recommended to create the server key pair before setting up the infrastructure. Store the downloaded keys securely.

## Terraform

Apply the Terraform template to construct the AWS cloud infrastructure.

You will need:

-   The name of the server key pair created in the previous step.
-   The S3 Bucket name you intend to create for assets.
-   The VPC ID where you intend to deploy the server.
-   The Route53 hostname for the record
-   The Route53 hosted zone ID

## Dependencies

Now that we have spun up the infrastructure, connect to the server via SSH using your stored server key.

-   Install node

```bash
sudo apt install -y libssl-dev
curl -sL https://deb.nodesource.com/setup_12.x | sudo bash -
sudo apt install -y nodejs
```

-   Install unzip

```bash
sudo apt install unzip
```

-   Make Foundry directories

```bash
cd $HOME
mkdir foundryvtt
mkdir foundrydata
```

## Foundry

Once you have paid for a Foundry VTT license, you'll have access to the foundry server package.

-   Download the Linux package locally

-   SCP Foundry package to the server

```bash
scp -i "/path/to/key.pem" foundryvtt-x.x.x.zip ubuntu@hostname:/home/ubuntu/foundryvtt/foundryvtt.zip
```

-   SCP foundry.service to the server

```bash
scp -i "/path/to/key.pem" foundry.service ubuntu@hostname:/home/ubuntu/foundryvtt/foundry.service
```

-   Unzip the server package

```bash
cd $HOME/foundryvtt
unzip foundryvtt.zip
```

-   Start the foundry service

```bash
sudo systemctl start foundry
sudo systemctl enable foundry
```

-   View the foundry status

```bash
sudo systemctl status foundry
```

At this point, you should see the service running and you will be able to connect to http://hostname:30000

Once you've connected to the server you'll be prompted to enter your licence and accep the EULA.

## Certbot

In order to sercure the server we will need to generate certificates. We'll be using LetsEncrypt through Certbot to accomplish this.

The instruction for setting up Certbot for our installation is here[https://certbot.eff.org/lets-encrypt/ubuntubionic-other].

Because the server is running as a service in the background and port 80 is free you can run certbot in standalone mode.

Follow the instructions until you get to the renewal hook:

```bash
sudo sh -c 'printf "#!/bin/sh\nsystemctl foundry stop\n" > /etc/letsencrypt/renewal-hooks/pre/foundry.sh'
sudo sh -c 'printf "#!/bin/sh\nsystemctl foundry start\n" > /etc/letsencrypt/renewal-hooks/post/foundry.sh'
sudo chmod 755 /etc/letsencrypt/renewal-hooks/pre/foundry.sh
sudo chmod 755 /etc/letsencrypt/renewal-hooks/post/foundry.sh
```

Now, if you run the dry run you should see certbot trigger the server stop and start.

```bash
sudo certbot renew --dry-run
journalctl -u foundry.service
```

With the certs generated, we need to change the owner to the `ubuntu` user.

```bash
sudo chown -R ubuntu /etc/letsencrypt
```

Now, on Foundry, navigate to the Configuration page and input the path to your new certs.

```bash
/etc/letsencrypt/live/hostname/cert.pem
/etc/letsencrypt/live/hostname/privkey.pem
```

The server will auto-restart upon saving the server configuration.

You will now have to access your server with HTTPS.

## Foundry S3 Access

Foundry VTT will need programatic user access for the S3 bucket and its data.

We already created the policy to access the bucket in TF.

-   Create a `foundryvtt` user in IAM and store the credentials securely.
-   Add the policy `FoundryS3Access` to the user.

## S3 Credentials

Foundry needs to be assigned the credentials for the foundry IAM user.

-   Add the aws.json in the `foundrydata/Config` folder.

```bash
{
  "accessKeyId": "FOUNDRYVTT_ACCESS_KEY_ID",
  "secretAccessKey": "FOUNDRYVTT_SECRET_ACCESS_KEY",
  "region": "YOUR_REGION"
}
```

-   Link the aws.json file in the server Configuration.

Once again, the server will auto-restart upon saving the server configuration.

## Admin Password

Now that we have a secure server we can add the admin password to prevent unauthorized access.

## Wrapping Up

You should now have a working Foundry VTT server running as a auto-restarting system service.
