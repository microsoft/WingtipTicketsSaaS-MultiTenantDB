using System.Collections.Generic;

namespace Events_TenantUserApp.EF.TenantsDB
{
    public partial class Venues
    {
        public Venues()
        {
            Customers = new HashSet<Customers>();
            Events = new HashSet<Events>();
            Sections = new HashSet<Sections>();
        }

        public int VenueId { get; set; }
        public string VenueName { get; set; }
        public string VenueType { get; set; }
        public string AdminEmail { get; set; }
        public string AdminPassword { get; set; }
        public string PostalCode { get; set; }
        public string CountryCode { get; set; }
        public byte[] RowVersion { get; set; }

        public virtual ICollection<Customers> Customers { get; set; }
        public virtual ICollection<Events> Events { get; set; }
        public virtual ICollection<Sections> Sections { get; set; }
        public virtual Countries CountryCodeNavigation { get; set; }
        public virtual VenueTypes VenueTypeNavigation { get; set; }
    }
}
