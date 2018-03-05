using System;

namespace Events_Tenant.Common.Models
{
    public class EventModel
    {
        public int EventId { get; set; }
        public DateTime Date { get; set; }
        public string EventName { get; set; }
        public string SubTitle { get; set; }
        public int VenueId { get; set; }
        public byte[] RowVersion { get; set; }
    }
}
