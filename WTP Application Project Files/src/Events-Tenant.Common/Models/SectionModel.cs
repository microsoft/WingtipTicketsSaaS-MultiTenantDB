namespace Events_Tenant.Common.Models
{
    public class SectionModel
    {
        public int SectionId { get; set; }
        public string SectionName { get; set; }
        public short SeatRows { get; set; }
        public short SeatsPerRow { get; set; }
        public decimal StandardPrice { get; set; }
        public int VenueId { get; set; }
        public byte[] RowVersion { get; set; }
    }
}

