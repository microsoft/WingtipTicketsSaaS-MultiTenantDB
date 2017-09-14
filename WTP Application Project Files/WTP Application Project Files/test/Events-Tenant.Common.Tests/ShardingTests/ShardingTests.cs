using System.Data.SqlClient;
using Events_Tenant.Common.Interfaces;
using Events_Tenant.Common.Utilities;
using Events_TenantUserApp.EF.CatalogDB;
using Microsoft.Azure.SqlDatabase.ElasticScale.ShardManagement;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Moq;

namespace Events_Tenant.Common.Tests.ShardingTests
{
    [TestClass]
    public class ShardingTests
    {
        #region Private fields

        //Use your local SQL Server instance name
        internal const string TestServer = @"localhost";
        
        //If your local instance does not support Windows Authentication change here for SQL Authentication
        internal const string ShardMapManagerTestConnectionString = "Data Source=" + TestServer + ";Integrated Security=True;";

        private const string CreateDatabaseQueryFormat =
            "IF EXISTS (SELECT name FROM sys.databases WHERE name = N'{0}') BEGIN DROP DATABASE [{0}] END CREATE DATABASE [{0}]";

        private CatalogConfig _catalogConfig;
        private DatabaseConfig _databaseConfig;
        private string _connectionString;

        private Mock<ICatalogRepository> _mockCatalogRepo;
        private Mock<ITenantRepository> _mockTenantRepo;
        private Mock<IUtilities> _mockUtilities;

        #endregion

        [TestInitialize]
        public void Setup()
        {
            _catalogConfig = new CatalogConfig
            {
                ServicePlan = "Standard",
                CatalogDatabase = "ShardMapManager",
                CatalogServer = TestServer
            };

            _databaseConfig = new DatabaseConfig
            {
                DatabasePassword = "",
                DatabaseUser = "",
                ConnectionTimeOut = 30,
                DatabaseServerPort = 1433,
                LearnHowFooterUrl = "",
                SqlProtocol = SqlProtocol.Tcp
            };

            var tenant = new Tenants
            {
                ServicePlan = "Standard",
                TenantName = "Test Tenant 1",
                TenantId = new byte[0]
            };

            _connectionString = string.Format("{0}Initial Catalog={1};", ShardMapManagerTestConnectionString, _catalogConfig.CatalogDatabase);

            _mockCatalogRepo = new Mock<ICatalogRepository>();
            _mockCatalogRepo.Setup(repo => repo.Add(tenant));

            _mockTenantRepo = new Mock<ITenantRepository>();

            _mockUtilities = new Mock<IUtilities>();

            #region Create databases on localhost

            // Clear all connection pools.
            SqlConnection.ClearAllPools();

            using (SqlConnection conn = new SqlConnection(ShardMapManagerTestConnectionString))
            {
                conn.Open();

                // Create ShardMapManager database
                using (SqlCommand cmd = new SqlCommand(string.Format(CreateDatabaseQueryFormat, _catalogConfig.CatalogDatabase), conn))
                {
                    cmd.ExecuteNonQuery();
                }

                // Create Tenant database
                using (SqlCommand cmd = new SqlCommand(string.Format(CreateDatabaseQueryFormat, tenant.TenantName), conn))
                {
                    cmd.ExecuteNonQuery();
                }

            }
            #endregion

        }

        [TestMethod]
        public void ShardingTest()
        {
            var sharding = new Sharding(_catalogConfig.CatalogDatabase, _connectionString, _mockCatalogRepo.Object, _mockTenantRepo.Object, _mockUtilities.Object);

            Assert.IsNotNull(sharding);
            Assert.IsNotNull(sharding.ShardMapManager);
        }

        [TestMethod]
        public async void RegisterShardTest()
        {
            _databaseConfig = new DatabaseConfig
            {
                SqlProtocol = SqlProtocol.Default
            };

            var sharding = new Sharding(_catalogConfig.CatalogDatabase, _connectionString, _mockCatalogRepo.Object, _mockTenantRepo.Object, _mockUtilities.Object);
            Assert.IsNotNull(sharding);

            var shard = Sharding.CreateNewShard("Test Tenant 1", TestServer, _databaseConfig.DatabaseServerPort, _catalogConfig.ServicePlan);
            Assert.IsNotNull(shard);

            var result = await Sharding.RegisterNewShard(397858529, _catalogConfig.ServicePlan, shard);
            Assert.IsTrue(result);
        }
    }
}
