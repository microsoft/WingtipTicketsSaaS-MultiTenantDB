using System.Data.SqlClient;
using Microsoft.Azure.SqlDatabase.ElasticScale.ShardManagement;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;

namespace Events_TenantUserApp.EF.TenantsDB
{
    public partial class TenantDbContext : DbContext
    {
        public virtual DbSet<Countries> Countries { get; set; }
        public virtual DbSet<Customers> Customers { get; set; }
        public virtual DbSet<EventSections> EventSections { get; set; }
        public virtual DbSet<Events> Events { get; set; }
        public virtual DbSet<Sections> Sections { get; set; }
        public virtual DbSet<TicketPurchases> TicketPurchases { get; set; }
        public virtual DbSet<Tickets> Tickets { get; set; }
        public virtual DbSet<VenueTypes> VenueTypes { get; set; }
        public virtual DbSet<Venues> Venues { get; set; }

        public TenantDbContext(ShardMap shardMap, int shardingKey, string connectionStr) :
            base(CreateDdrConnection(shardMap, shardingKey, connectionStr))
        {

        }

        /// <summary>
        /// Creates the DDR (Data Dependent Routing) connection.
        /// </summary>
        /// <param name="shardMap">The shard map.</param>
        /// <param name="shardingKey">The sharding key.</param>
        /// <param name="connectionStr">The connection string.</param>
        /// <returns></returns>
        private static DbContextOptions CreateDdrConnection(ShardMap shardMap, int shardingKey, string connectionStr)
        {
            // Ask shard map to broker a validated connection for the given key
            SqlConnection sqlConn = shardMap.OpenConnectionForKey(shardingKey, connectionStr);

            // Set TenantId in SESSION_CONTEXT to shardingKey to enable Row-Level Security filtering
            SqlCommand cmd = sqlConn.CreateCommand();
            cmd.CommandText = @"exec sp_set_session_context @key=N'TenantId', @value=@shardingKey";
            cmd.Parameters.AddWithValue("@shardingKey", shardingKey);
            cmd.ExecuteNonQuery();

            var optionsBuilder = new DbContextOptionsBuilder<TenantDbContext>();
            var options = optionsBuilder.UseSqlServer(sqlConn).Options;

            return options;
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Countries>(entity =>
            {
                entity.HasKey(e => e.CountryCode)
                    .HasName("PK__Countrie__5D9B0D2D633BFAC4");

                entity.HasIndex(e => new { e.CountryCode, e.Language })
                    .HasName("IX_Countries_Country_Language")
                    .IsUnique();

                entity.Property(e => e.CountryCode).HasColumnType("char(3)");

                entity.Property(e => e.CountryName)
                    .IsRequired()
                    .HasMaxLength(50);

                entity.Property(e => e.Language)
                    .IsRequired()
                    .HasMaxLength(10)
                    .HasDefaultValueSql("'en'");
            });

            modelBuilder.Entity<Customers>(entity =>
            {
                entity.HasKey(e => new { e.VenueId, e.CustomerId })
                    .HasName("PK__Customer__A61D03BFF90DA059");

                entity.HasIndex(e => e.Email)
                    .HasName("IX_Customers_Email")
                    .IsUnique();

                entity.HasIndex(e => new { e.VenueId, e.Email })
                    .HasName("AK_Venue_Email")
                    .IsUnique();

                entity.Property(e => e.CustomerId).ValueGeneratedOnAdd();

                entity.Property(e => e.CountryCode)
                    .IsRequired()
                    .HasColumnType("char(3)");

                entity.Property(e => e.Email)
                    .IsRequired()
                    .HasColumnType("varchar(128)");

                entity.Property(e => e.FirstName)
                    .IsRequired()
                    .HasMaxLength(50);

                entity.Property(e => e.LastName)
                    .IsRequired()
                    .HasMaxLength(50);

                entity.Property(e => e.Password).HasMaxLength(30);

                entity.Property(e => e.PostalCode).HasMaxLength(20);

                entity.Property(e => e.RowVersion)
                    .IsRequired()
                    .HasColumnType("timestamp")
                    .ValueGeneratedOnAddOrUpdate();

                entity.HasOne(d => d.CountryCodeNavigation)
                    .WithMany(p => p.Customers)
                    .HasForeignKey(d => d.CountryCode)
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_Customers_Countries");

                entity.HasOne(d => d.Venue)
                    .WithMany(p => p.Customers)
                    .HasForeignKey(d => d.VenueId)
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_Customers_Venues");
            });

            modelBuilder.Entity<EventSections>(entity =>
            {
                entity.HasKey(e => new { e.VenueId, e.EventId, e.SectionId })
                    .HasName("PK__EventSec__5843467B336CA8CB");

                entity.Property(e => e.Price).HasColumnType("money");

                entity.Property(e => e.RowVersion)
                    .HasColumnType("timestamp")
                    .ValueGeneratedOnAddOrUpdate();

                entity.HasOne(d => d.Events)
                    .WithMany(p => p.EventSections)
                    .HasForeignKey(d => new { d.VenueId, d.EventId })
                    .HasConstraintName("FK_EventSections_Events");

                entity.HasOne(d => d.Sections)
                    .WithMany(p => p.EventSections)
                    .HasForeignKey(d => new { d.VenueId, d.SectionId })
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_EventSections_Sections");
            });

            modelBuilder.Entity<Events>(entity =>
            {
                entity.HasKey(e => new { e.VenueId, e.EventId })
                    .HasName("PK__Events__2BC3A973FC7547E0");

                entity.Property(e => e.EventId).ValueGeneratedOnAdd();

                entity.Property(e => e.Date).HasColumnType("datetime");

                entity.Property(e => e.EventName)
                    .IsRequired()
                    .HasMaxLength(50);

                entity.Property(e => e.RowVersion)
                    .IsRequired()
                    .HasColumnType("timestamp")
                    .ValueGeneratedOnAddOrUpdate();

                entity.Property(e => e.Subtitle).HasMaxLength(50);

                entity.HasOne(d => d.Venue)
                    .WithMany(p => p.Events)
                    .HasForeignKey(d => d.VenueId)
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_Events_Venues");
            });

            modelBuilder.Entity<Sections>(entity =>
            {
                entity.HasKey(e => new { e.VenueId, e.SectionId })
                    .HasName("PK__Sections__045915751CA4F790");

                entity.Property(e => e.SectionId).ValueGeneratedOnAdd();

                entity.Property(e => e.RowVersion)
                    .IsRequired()
                    .HasColumnType("timestamp")
                    .ValueGeneratedOnAddOrUpdate();

                entity.Property(e => e.SeatRows).HasDefaultValueSql("20");

                entity.Property(e => e.SeatsPerRow).HasDefaultValueSql("30");

                entity.Property(e => e.SectionName)
                    .IsRequired()
                    .HasMaxLength(30);

                entity.Property(e => e.StandardPrice)
                    .HasColumnType("money")
                    .HasDefaultValueSql("10");

                entity.HasOne(d => d.Venue)
                    .WithMany(p => p.Sections)
                    .HasForeignKey(d => d.VenueId)
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_Sections_Venues");
            });

            modelBuilder.Entity<TicketPurchases>(entity =>
            {
                entity.HasKey(e => new { e.VenueId, e.TicketPurchaseId })
                    .HasName("PK__TicketPu__4521662FD0E33D91");

                entity.HasIndex(e => e.CustomerId)
                    .HasName("IX_TicketPurchases_CustomerId");

                entity.Property(e => e.TicketPurchaseId).ValueGeneratedOnAdd();

                entity.Property(e => e.PurchaseDate).HasColumnType("datetime");

                entity.Property(e => e.PurchaseTotal).HasColumnType("money");

                entity.Property(e => e.RowVersion)
                    .IsRequired()
                    .HasColumnType("timestamp")
                    .ValueGeneratedOnAddOrUpdate();

                entity.HasOne(d => d.Customers)
                    .WithMany(p => p.TicketPurchases)
                    .HasForeignKey(d => new { d.VenueId, d.CustomerId })
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_TicketPurchases_Customers");
            });

            modelBuilder.Entity<Tickets>(entity =>
            {
                entity.HasKey(e => new { e.VenueId, e.TicketId })
                    .HasName("PK__Tickets__5B45299265DF399F");

                entity.HasIndex(e => new { e.EventId, e.SectionId, e.RowNumber, e.SeatNumber })
                    .HasName("IX_Tickets")
                    .IsUnique();

                entity.Property(e => e.TicketId).ValueGeneratedOnAdd();

                entity.HasOne(d => d.TicketPurchases)
                    .WithMany(p => p.Tickets)
                    .HasForeignKey(d => new { d.VenueId, d.TicketPurchaseId })
                    .HasConstraintName("FK_Tickets_TicketPurchases");

                entity.HasOne(d => d.EventSections)
                    .WithMany(p => p.Tickets)
                    .HasForeignKey(d => new { d.VenueId, d.EventId, d.SectionId })
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_Tickets_EventSections");
            });

            modelBuilder.Entity<VenueTypes>(entity =>
            {
                entity.HasKey(e => e.VenueType)
                    .HasName("PK__VenueTyp__265E44FD2C12EA43");

                entity.HasIndex(e => new { e.VenueTypeName, e.Language })
                    .HasName("IX_VENUETYPES_VENUETYPENAME_LANGUAGE")
                    .IsUnique();

                entity.Property(e => e.VenueType).HasMaxLength(30);

                entity.Property(e => e.EventTypeName)
                    .IsRequired()
                    .HasMaxLength(30);

                entity.Property(e => e.EventTypeShortName)
                    .IsRequired()
                    .HasMaxLength(20);

                entity.Property(e => e.EventTypeShortNamePlural)
                    .IsRequired()
                    .HasMaxLength(20);

                entity.Property(e => e.Language)
                    .IsRequired()
                    .HasMaxLength(10);

                entity.Property(e => e.VenueTypeName)
                    .IsRequired()
                    .HasMaxLength(30);
            });

            modelBuilder.Entity<Venues>(entity =>
            {
                entity.HasKey(e => e.VenueId)
                    .HasName("PK_Venues");

                entity.HasIndex(e => e.CountryCode)
                    .HasName("IX_Venues_CountryCode");

                entity.HasIndex(e => e.VenueType)
                    .HasName("IX_Venues_VenueType");

                entity.Property(e => e.VenueId).ValueGeneratedNever();

                entity.Property(e => e.AdminEmail)
                    .IsRequired()
                    .HasMaxLength(128);

                entity.Property(e => e.AdminPassword).HasMaxLength(30);

                entity.Property(e => e.CountryCode)
                    .IsRequired()
                    .HasColumnType("char(3)");

                entity.Property(e => e.PostalCode).HasMaxLength(20);

                entity.Property(e => e.RowVersion)
                    .IsRequired()
                    .HasColumnType("timestamp")
                    .ValueGeneratedOnAddOrUpdate();

                entity.Property(e => e.VenueName)
                    .IsRequired()
                    .HasMaxLength(50);

                entity.Property(e => e.VenueType)
                    .IsRequired()
                    .HasMaxLength(30);

                entity.HasOne(d => d.CountryCodeNavigation)
                    .WithMany(p => p.Venues)
                    .HasForeignKey(d => d.CountryCode)
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_Venues_Countries");

                entity.HasOne(d => d.VenueTypeNavigation)
                    .WithMany(p => p.Venues)
                    .HasForeignKey(d => d.VenueType)
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_Venues_VenueTypes");
            });
        }
    }
}