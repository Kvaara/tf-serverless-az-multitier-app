# Terraform Serverless Azure Multi-Tier Application

This was an exercise from the book [Terraform In Action](https://www.amazon.com/Terraform-Action-Scott-Winkler/dp/1617296899), which I've uplifted and fixed here.

I always knew that serverless or event-driven architecture was super economical/cheap but I had no idea that it was this powerful and practical.

With Serverless Architecture comes Functions-as-a-service (FaaS) model and, with functions (two in this case: `api` and `web`), you can deploy a static multi-tiered web application.

- You can implement the Presentation (frontend) and Service (backend/API) layers as functions. This means that you can achieve astronomical cost savings in comparison to traditional servers that often run 24/7/365.
- Data layer can be implemented via the [Azure Table Storage](https://learn.microsoft.com/en-us/azure/storage/tables/table-storage-overview), which wraps around the Azure Storage Service. This isn't only cheaper but more simplistic than traditional SQL. Azure Table Storage is similar to [Azure Cosmos DB](https://learn.microsoft.com/en-us/azure/cosmos-db/table/support?toc=https%3A%2F%2Flearn.microsoft.com%2Fen-us%2Fazure%2Fstorage%2Ftables%2Ftoc.json&bc=https%3A%2F%2Flearn.microsoft.com%2Fen-us%2Fazure%2Fbread%2Ftoc.json).

**This might actually be a multi-tier application you could easily host for pennies 24/7/365 :D**

I'll deploy this same application to Oracle Cloud Infrastructure (OCI) just to see how much more difficult and verbose it is. Based on my preliminary analysis, there will be much more configuration and additional resources that must be created (e.g., networking, API Gateway, replacing Azure SDK with OCI's and so on).

- See [tf-serverless-oci-multi-tier-app](https://github.com/Kvaara/tf-serverless-oci-multi-tier-app/tree/main).

## Flaws

There are some flaws with this current architecture and that's the lack of request limiting or throttling. People with bad intent (bad/malicious actors) could spam your `api` function and send large amounts of queries to Azure Table Storage. This could be fixed by incorporating [Azure API Management (APIM)](https://learn.microsoft.com/en-us/azure/api-management/api-management-key-concepts). If I've understood it correctly, APIM works seamlessly with Azure Functions.

Also, in the `host.json` configuration file, which applies to ALL the Functions in a Function App, you can limit the amount of concurrent executions/invocations with `maxConcurrentRequests` and `maxOutstandingRequests`. See [host.json settings](https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-http-webhook?tabs=isolated-process%2Cfunctionsv2&pivots=programming-language-javascript#hostjson-settings) for more information.

Lastly, you could reduce the *scale-out behavior* of functions with the `site_config` setting called `app_scale_limit` (*as we have done*). See [Scaling](https://learn.microsoft.com/en-us/azure/azure-functions/functions-scale#scale) for more information related to the Consumption plan.

- 10maxConcurrentRequests * 5app_scale_limit = 50 RPS (requests per second)

## How To Deploy

1. Register for an [Azure cloud account](https://azure.microsoft.com/en-us/pricing/purchase-options/azure-account).
2. Install [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/) and authenticate via its `az login` command.
3. Find your subscription ID from the Azure portal and replace the `null` value in the [terraform.tfvars](./terraform.tfvars) file with it.
4. Run `terraform apply`.
5. Afterwards, Terraform should print an output to the terminal with a workable link to your deployed serverless multi-tier application.

## Supplementary

[v3 of Azure Functions Node.js developer guide](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-node?pivots=nodejs-model-v3&tabs=javascript%2Cwindows%2Cazure-cli#inputs-and-outputs).
