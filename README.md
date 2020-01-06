The script would read data from a csv file and upload it to the configured **hr connector** job.

## Creating AAD APP

Create you AAD APP https://docs.microsoft.com/en-us/azure/kusto/management/access-control/how-to-provision-aad-app

 Note the following
 - APP_ID (aka Application ID or Client)
 - APP_SECRET (aka client secret)
 - TENANT_ID (aka directory ID)

## Create your job on SCC

Provide required Details at HR Connector and create a job and note the **JOB_ID**

## Run the powershell script
```powershell
.\upload_csv_for_hr_termination.ps1 -tenantId <TENANT_ID> -appId <APP_ID>  -appSecret <APP_SECRET>  -jobId <JOB_ID>  -csvFilePath <CSV_FILE_PATH>
```

CSV_FILE_PATH should be the local file path for the csv data to upload.

 If the last line reads **Upload Successful**, the script execution was successful. 

The script would retry  over a period of about 15 mins if it encounters any transient failures.

## CSV criteria

- the columns names should match the ones setup while creating a job

- the dates should be in `yyyy-mm-ddThh:mm:ss.nnnnnn+|-hh:mm` format.  Sample dates as below

  - 2008-09-15T15:53:00+05:00 
  - 2008-09-15T15:53:00Z

  #### Sample CSV

  | ResignationDate                   | UserEmailAddress       | LastWorkingDate                   |
  | --------------------------------- | ---------------------- | --------------------------------- |
  | 2019-04-29T15:18:02.4675041+05:30 | testing1@microsoft.com | 2019-04-23T15:18:02.4675041+05:30 |
  | 2019-04-24T09:15:49Z              | testing2@microsoft.com | 2019-04-23T15:18:02.4675041       |

## Common Errors and resolution

1. JOB_ID might be incorrect. Make sure it matches the one configured on SCC

> RetryCommand : Failure with StatusCode [Forbidden] and ReasonPhrase [jobId and corresponding appId do not match.]
> 

2. APP_ID or TENANT_ID might be incorrect.

> RetryCommand : {"error":"unauthorized_client","error_description":"AADSTS700016: Application with identifier '689412fa-4b24-475a-ab39-32eca848b6f2' was 
> not found in the directory '85ee0691-54d7-49f1-b879-3ce53c2a8549'. This can happen if the application has not been installed by the administrator of the 
> tenant or consented to by any user in the tenant. You may have sent your authentication request to the wrong tenant.}