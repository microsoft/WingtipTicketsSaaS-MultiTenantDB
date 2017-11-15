using System.Data.Common;
using Microsoft.Azure.SqlDatabase.ElasticScale.ShardManagement;

namespace Events_TenantUserApp.EF.TenantsDdEF6
{
    using System.Data.Entity;
    using System.Data.SqlClient;

    public partial class TenantContext : DbContext
    {
        public TenantContext()
            : base("name=TenantContext")
        {
        }

        public TenantContext(ShardMap shardMap, int shardingKey, string connectionStr)
            : base(CreateDdrConnection(shardMap, shardingKey, connectionStr), true)
        {

        }

        private static DbConnection CreateDdrConnection(ShardMap shardMap, int shardingKey, string connectionStr)
        {
            // No initialization
            Database.SetInitializer<TenantContext>(null);

            // Ask shard map to broker a validated connection for the given key
            SqlConnection sqlConn = shardMap.OpenConnectionForKey(shardingKey, connectionStr);

            // Set TenantId in SESSION_CONTEXT to shardingKey to enable Row-Level Security filtering
            SqlCommand cmd = sqlConn.CreateCommand();
            cmd.CommandText = @"exec sp_set_session_context @key=N'TenantId', @value=@shardingKey";
            cmd.Parameters.AddWithValue("@shardingKey", shardingKey);
            cmd.ExecuteNonQuery();

            return sqlConn;
        }

        public virtual DbSet<EventsWithNoTicket> EventsWithNoTickets { get; set; }
        public virtual DbSet<database_firewall_rules> database_firewall_rules { get; set; }

        protected override void OnModelCreating(DbModelBuilder modelBuilder)
        {
            modelBuilder.Entity<database_firewall_rules>()
                .Property(e => e.start_ip_address)
                .IsUnicode(false);

            modelBuilder.Entity<database_firewall_rules>()
                .Property(e => e.end_ip_address)
                .IsUnicode(false);
        }
    }
}
