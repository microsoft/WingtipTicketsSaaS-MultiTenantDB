## WingtipTicketsSaaS-MultiTenantDB
Sample multi-tenant SaaS application and management scripts built on SQL Database using a sharded multi-tenant database model. This contrasts with the strict database-per-tenant model used in the base WingtipSaaS sample. 

This project provides a sample SaaS application that embodies many common SaaS patterns that can be used with Azure SQL Database.  The sample is based on an event-management and ticket-selling scenario for small venues.  Each venue is a 'tenant' of the SaaS application. The application is functionally identical to the other Wingtip Tickets SaaS samples.  

The sharded multi-tenant database model used in this sample enables a tenants database to contain any number of tenants.  This sample explores the potential to use a mix of a multi-tenant and single-tenant databases, enabling a 'hybrid' tenant management model.  Databases containing large numbers of tenants are configured as stand-alone databases with the appropriate performance level (DTUs) for their aggregate workload.  While databases with only a single tenant are hosted by default in elastic pools where the elastic pool is assigned the appropriate eDTU level for the aggregate workload of all the databases in the pool. 

Using this hybrid approach, multi-tenant databases can be used to host very large numbers of infrequently used tenants, while single-tenant databases can  be used to host more frequently used databases, or databases that need greater isolation and potentially individual management.  This management flexibility is achieved without needing to change the application.  In general, multi-tenant databases can have the lowest per-tenant cost, traded off against lower levels of tenant isolation.  Multi-tenant databases might be used to host tenants that are trialing a service, perhaps at no or little charge, while single-tenant databases might host tenants on paying plans or those paying a premium price.  Single-tenant databases benefit from greater database isolation, enabling improved security, better performance isolation that allows per-tenant performance monitoring and the option to move moving individual tenant databases between pools or to be moved out of a pool and assigned individual resources during periods of intense activity, etc.    

An additional catalog database holds the mapping between tenants and their databases, regardless of number of tenants per database.  This mapping is managed using the Shard Map Management features of the Elastic Scale Client Library.  

The basic application when installed includes three pre-defined venues in a single multi-tenant database.  The application is installed in your Azure subscription under a single ARM resource group.  To uninstall the application, delete the resource group from the Azure Portal. 

Management scripts are provided to allow you to explore many management scenarios, including adding tenants and moving tenants into isolated databases.  

NOTE: if you install the application you will be charged for the Azure resources created.  Actual costs incurred are based on your subscription offer type but are nominal if the application is not scaled up unreasonably and is deleted promptly after you have finished exploring the tutorials.

More information about the sample app and the associated tutorials is here: <TBD> 

Also available in the Documentation folder in this repo is an **overview presentation** that provides background, explores alternative database models for multi-tenant apps, and walks through several of the SaaS patterns at a high level. There is also a demo script you can use with the presentation to give others a guided tour of the app and several of the patterns.

To deploy the app to Azure, click the link below.  Deploy the app in a new resource group, and provide a short *user* value that will be appended to several resource names to make them globally unique.  Your initials and a number is a good pattern to use.


<a href="http://aka.ms/deploywtp-mtapp" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>


After deployment completes, launch the app by browsing to ```http://events.wtp-mt.USER.trafficmanager.net```, substituting *USER* with the value you set during deployment. 

**IMPORTANT:** If you download and extract the repo or [Learning Modules](https://github.com/Microsoft/WingtipSaaS-MT/tree/master/Learning%20Modules) from a zip file, make sure you unblock the .zip file before extracting. Executable contents (scripts, dlls) may be blocked by Windows when zip files are downloaded from an external source and extracted.

To avoid scripts from being blocked by Windows:

1. Right click the zip file and select **Properties**.
1. On the **General** tab, select **Unblock** and select **OK**.


## License
Microsoft Wingtip SaaS sample application and tutorials are licensed under the MIT license. See the [LICENSE](https://github.com/Microsoft/WingtipSaaS-MT/blob/master/license) file for more details.

# Contributing

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
