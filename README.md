## WingtipSaaS - Hybrid Sharded Multi-Tenant Database
Sample SaaS application and management scripts built using a hybrid sharded multi-tenant database model. 

This project provides a sample SaaS application that embodies many common SaaS patterns that can be used with Azure SQL Database.  The sample is based on an event-management and ticket-selling scenario for small venues.  Each venue is a 'tenant' of the SaaS application.  

The sample uses a hybrid sharded multi-tenant database model.  With this model a database contains one or more tenants.  While any mapping of tenants to databases is possible, a database might typically contain either multiple, potentially large numbers of tenants, or a single tenant.  Databases containing a large number of tenants will typically be configured as stand-alone databases with the appropriate performance level (DTUs) for the aggregate workload.  Where databases contain only a single tenant might typically be hosted in elastic pools, where each elastic pool has the appropriate eDTU level for the aggregate workload across all the databases in the pool. 

In this hybrid model, multi-tenant databases might host large numbers of infrequently used tenants, while single-tenant databases are used to host more frequently used databases, or databases that need greater isolation and potentially individual management.  Multi-tenant databases, for example, might be used to host tenants that are trialing a service, perhaps at no charge, while single-tenant databases might host tenants on paying plans.  Single-tenant databases can be managed using the same management approaches used for the full-time database-per-tenant model, including individual tenant/database performance monitoring, load-balancing between pools, moving databases out of pools during periods of intense activity, etc.  

An additional catalog database holds the mapping between tenants and their databases, regardless of number of tenants per database.  This mapping is managed using the Shard Map Management features of the Elastic Scale Client Library.  

The basic application, which includes three pre-defined venues installed in a single multi-tenant database, can be installed in your Azure subscription under a single ARM resource group.  To uninstall the application, delete the resource group from the Azure Portal. 

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
