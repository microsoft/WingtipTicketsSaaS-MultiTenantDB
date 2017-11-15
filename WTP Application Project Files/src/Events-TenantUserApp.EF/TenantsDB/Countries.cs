using System.Collections.Generic;

namespace Events_TenantUserApp.EF.TenantsDB
{
    public partial class Countries
    {
        public Countries()
        {
            Customers = new HashSet<Customers>();
            Venues = new HashSet<Venues>();
        }

        public string CountryCode { get; set; }
        public string CountryName { get; set; }
        public string Language { get; set; }

        public virtual ICollection<Customers> Customers { get; set; }
        public virtual ICollection<Venues> Venues { get; set; }
    }
}
