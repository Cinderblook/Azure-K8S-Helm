# Overview
 Deplying helm charts in Kubernetes within Azure using the AKS service.
 <br> 
 
 *This guide is essneitally a part 2, with part 1 being my Azure Terraform deployment using just the Kubernetes provider. Check out part one on my [Github Repo]() or on my [Site]()*

 - Build a cluster that is running a few services 
 - Have cluster automatically scale with load
 - Have Kubeconfig file available so it can be managed, changed, altered, destroyed, etc.
 - Ensure Kubeconfig file is secure, and is being encrypted with traffic involved in this
 - Create a NGINX certificate service utilizing Cloudflare's DNS
 - Use Traefik as a loadbalancer, and utilize ingresses for reachable internal services

# Steps to do this
1. Have an Azure account 
    - *[if you are a student, sign up for a student account and get some free credits along side it.](https://azure.microsoft.com/en-us/free/students/)*
2. Create a public and private key
3. Setup Cloudflare 
    - Create an account if you have not done so yet
    - Obtain a public domain
    - Generate a Token for DNS Read and write access
4. Setup Terraform files for the deployment
    - I'll guide along the process here in this post. Although, feel free to reference the [Github page]() for this as well for a more condensed code location.
5. Keep track of Terraform State and Kubeconfig files in order to continue managaing deployed resources

# Creating the Public & Private keys
First step we'll tackle is the creation of your public and private keys. 

I find the easiest way to do this, is to open up a terminal (Powershell and/or pretty much any linux terminal) and type in a quick few commands. To keep it short and sweet, we will just use `ssh-keygen`

![SSH-Keygen-Example](/examples/SSH-keygen-example1.png 'ssh-keygen-example1') 

Ensure you save this to a locaiton you will remember, it'll be important not to loose either key. This'll allow you SSH access into your Kubernetes cluster.

Copy your public key you genereated into the same folder as your .tf files will be located.

# Setting up Cloudflare
Second step on our list, is to setup Cloudflare.

Cloudflare is important here, since it will be handing out certificates to services running within the Kubernetes cluster. Luckily, [signing up for Cloudflare is free](https://dash.cloudflare.com/login), and I'll go over how to obtain a Token for API access.

Once you have created your account, and have obtained a public domain, you should see a page similar to the following; 

![Cloudflare Overview Page](/examples/Cloudflare-example1.png 'Cloudflare Overview Page')

Scroll down on the overview tab, and on the right hand side, there should be a 'Get your API token' link. On the following page, click 'Create token'

![Cloudflare Token Creation](/examples/Cloudflare-example2.png 'Cloudflare Token Creation')

Scroll down to the bottom, and select 'Create Custom Token`. On the following page, ensure you give your token a memorable name, assign it permissions to read and edit DNS zone settings, and limit it to your respective Zone resources (Domain). Set the TTL to the duration of your project.

![Cloudflare Token Policy](/examples/Cloudflare-example3.png 'Cloudflare Token Policy')

Continue to summary, and collect the API token key, store it discretely. This Token will be used in Terraform, within the .tfvars file later for authentication with the Cloudflare API.

# Terraform Process
## Setting up Providers; Azurerm, Kubernetes, Helm
.
## Setting up Kubernetes structure
.
## Using Helm to deploy containers on cluster
.
## Assigning variable to variables.tfvars
Assign correct Cloudflare information into the .tfvars file. Follow along with the example file. <br>
Refer to this [Cloudflare](https://developers.cloudflare.com/api/tokens/create/#:~:text=Log%20into%20your%20Cloudflare%20account,new%20API%20token%20secret%20key.) guide for getting API keys

### As for the SSH key, ensure you have a .pub file that you are pulling data from, or directly put SSH key into into variable file.

## Creating output to be sent back after Terraform finishes running


## Gain access to Kubectl
In order to gain access from your local machine, we will use the azure CLI. If you followed the tutorial, you'll already be logged in, `az login`. Use the following command to set your environment varialbe for kubectl to control kubernetes cluster in Azure.
`az aks get-credentials --resource-group $(terraform output -raw resource_group_name) --name $(terraform output -raw cluster_name)`

Once ran, you can verify it is connected and working with `kubectl get nodes` , `kubectl get namespace`

## Now what?
Congragulations! The hard part of getting started, is now over. You now have a ready to spin up AKS cluster in Azure prebuilt with a loadbalancer and certificate automation. From here, the possibilites are limitless. 

# Useful Resources
* [Kubernetes Overview](https://learnk8s.io/terraform-aks)
* [Terraform Kubernetes](https://registry.terraform.io/providers/hashicorp/kubernetes/latest)
* [Terraform Azurerm](https://registry.terraform.io/providers/hashicorp/azurerm/latest)
* [Terraform Helm](https://registry.terraform.io/providers/hashicorp/helm/2.5.0)
https://github.com/xcad2k/boilerplates/tree/main/terraform/templates/kubernetes-automation-example
https://www.youtube.com/watch?v=kFt0OGd_LhI&t=870s