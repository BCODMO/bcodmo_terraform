# sm_ui
Terraform scripts for semantic annotations to dataset parameters architecture


You will need to manually create the state bucket and dynamoDB table. See backend.tf file for information about those resources. After that you'll need to import those resources like:

```
terraform import aws_dynamodb_table.terraform_locks sm-ui-terraform-locks;
terraform import aws_s3_bucket.terraform_state bcodmo-sm-ui-terraform-state;
```


You will need to import the https certificate. For example:

```
terraform import aws_acm_certificate.cert arn:aws:acm:us-east-1:504672911985:certificate/7d76e817-d2dc-44e6-902c-d9cb8898e6f2
```

To get the Voila server running, ssh to the EC2 instance using the "sm_ui" keypair

`ssh -i ~/.aws/sm_ui.pem ubuntu@public_ipv4_dns_address`


Then, follow these instructions (copied from https://voila.readthedocs.io/en/stable/deploy.html):




    1. SSH into the server:

        `ssh ubuntu@<ip-address>`

    Install nginx:

        `sudo apt install nginx`

    To check that nginx is correctly installed:

        `sudo systemctl status nginx`

    Create the file /etc/nginx/sites-enabled/yourdomain.com with the following content:

        ```
        server {
            listen 80;
            server_name yourdomain.com;
            proxy_buffering off;
            location / {
                    proxy_pass http://localhost:8866;
                    proxy_set_header Host $host;
                    proxy_set_header X-Real-IP $remote_addr;
                    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

                    proxy_http_version 1.1;
                    proxy_set_header Upgrade $http_upgrade;
                    proxy_set_header Connection "upgrade";
                    proxy_read_timeout 86400;
            }

            client_max_body_size 100M;
            error_log /var/log/nginx/error.log;
        }
        ```

    Enable and start the nginx service:

        ```
        sudo systemctl enable nginx.service
        sudo systemctl start nginx.service
        ```

    Install pip:

        `sudo apt update && sudo apt install python3-pip`

    Follow the instructions in Setup an example project, and install the dependencies:

        `sudo python3 -m pip install -r requirements.txt`

    8. Create a new systemd service for running Voilà in /usr/lib/systemd/system/voila.service. The service will ensure Voilà is automatically restarted on startup:

    ```
    [Unit]
    Description=Voila

    [Service]
    Type=simple
    PIDFile=/run/voila.pid
    ExecStart=voila --no-browser voila/notebooks/basics.ipynb
    User=ubuntu
    WorkingDirectory=/home/ubuntu/
    Restart=always
    RestartSec=10

    [Install]
    WantedBy=multi-user.target
    ```

In this example Voilà is started with voila --no-browser voila/notebooks/basics.ipynb to serve a single notebook. You can edit the command to change this behavior and the notebooks Voilà is serving.

    Enable and start the voila service:

    ```
        sudo systemctl enable voila.service
        sudo systemctl start voila.service
    ```


