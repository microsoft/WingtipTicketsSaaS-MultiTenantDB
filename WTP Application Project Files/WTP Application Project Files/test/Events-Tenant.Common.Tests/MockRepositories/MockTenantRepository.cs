using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Events_Tenant.Common.Interfaces;
using Events_Tenant.Common.Models;

namespace Events_Tenant.Common.Tests.MockRepositories
{
    public class MockTenantRepository : ITenantRepository
    {
        #region Private Variables
        private List<CountryModel> Countries { get; set; }
        private List<CustomerModel> CustomerModels { get; set; }
        private List<EventSectionModel> EventSectionModels { get; set; }
        private List<SectionModel> SectionModels { get; set; }
        private List<TicketPurchaseModel> TicketPurchaseModels { get; set; }
        private List<TicketModel> TicketModels { get; set; }
        private List<EventModel> EventModels { get; set; }
        private List<VenuesModel> VenuesModels { get; set; }
        #endregion

        public MockTenantRepository()
        {
            var country = new CountryModel
            {
                Language = "en-us",
                CountryCode = "USA",
                CountryName = "United States"
            };
            Countries = new List<CountryModel> { country };

            CustomerModels = new List<CustomerModel>();

            EventSectionModels = new List<EventSectionModel>
            {
                new EventSectionModel
                {
                    SectionId = 1,
                    EventId = 1,
                    Price = 100,
                    VenueId = -1929398168
                },
                new EventSectionModel
                {
                    SectionId = 2,
                    EventId = 1,
                    Price = 80,
                    VenueId = -1929398168
                },
                new EventSectionModel
                {
                    SectionId = 3,
                    EventId = 1,
                    Price = 60,
                    VenueId = -1929398168
                },
                new EventSectionModel
                {
                    SectionId = 1,
                    EventId = 1,
                    Price = 100,
                    VenueId = 1032943028
                },
                new EventSectionModel
                {
                    SectionId = 2,
                    EventId = 1,
                    Price = 80,
                    VenueId = 1032943028
                },
                new EventSectionModel
                {
                    SectionId = 3,
                    EventId = 1,
                    Price = 60,
                    VenueId = 1032943028
                }
            };

            SectionModels = new List<SectionModel>
            {
                new SectionModel
                {
                    SectionId = 1,
                    SeatsPerRow = 10,
                    SectionName = "section 1",
                    StandardPrice = 100,
                    SeatRows = 4,
                    VenueId = -1929398168
                },
                new SectionModel
                {
                    SectionId = 2,
                    SeatsPerRow = 20,
                    SectionName = "section 2",
                    StandardPrice = 80,
                    SeatRows = 5,
                    VenueId = -1929398168
                },
                new SectionModel
                {
                    SectionId = 1,
                    SeatsPerRow = 10,
                    SectionName = "section 1",
                    StandardPrice = 100,
                    SeatRows = 4,
                    VenueId = 1032943028
                },
                new SectionModel
                {
                    SectionId = 2,
                    SeatsPerRow = 20,
                    SectionName = "section 2",
                    StandardPrice = 80,
                    SeatRows = 5,
                    VenueId = 1032943028
                }
            };

            TicketPurchaseModels = new List<TicketPurchaseModel>
            {
                new TicketPurchaseModel
                {
                    CustomerId = 1,
                    PurchaseTotal = 2,
                    TicketPurchaseId = 5,
                    PurchaseDate = DateTime.Now,
                    VenueId = -1929398168
                },
                new TicketPurchaseModel
                {
                    CustomerId = 1,
                    PurchaseTotal = 2,
                    TicketPurchaseId = 5,
                    PurchaseDate = DateTime.Now,
                    VenueId = 1032943028
                }
            };

            TicketModels = new List<TicketModel>
            {
                new TicketModel
                {
                    SectionId = 1,
                    EventId = 1,
                    TicketPurchaseId = 12,
                    SeatNumber = 50,
                    RowNumber = 2,
                    TicketId = 2,
                    VenueId = -1929398168
                },
                new TicketModel
                {
                    SectionId = 1,
                    EventId = 1,
                    TicketPurchaseId = 12,
                    SeatNumber = 50,
                    RowNumber = 2,
                    TicketId = 2,
                    VenueId = 1032943028
                }
            };

            EventModels = new List<EventModel>
            {
                new EventModel
                {
                    EventId = 1,
                    EventName = "Event 1",
                    Date = DateTime.Now,
                    SubTitle = "Event 1 Subtitle",
                    VenueId = -1929398168
                },
                new EventModel
                {
                    EventId = 2,
                    EventName = "Event 2",
                    Date = DateTime.Now,
                    SubTitle = "Event 2 Subtitle",
                    VenueId = -1929398168
                },
                new EventModel
                {
                    EventId = 1,
                    EventName = "Event 1",
                    Date = DateTime.Now,
                    SubTitle = "Event 1 Subtitle",
                    VenueId = 1032943028
                },
                new EventModel
                {
                    EventId = 2,
                    EventName = "Event 2",
                    Date = DateTime.Now,
                    SubTitle = "Event 2 Subtitle",
                    VenueId = 1032943028
                }
            };

            VenuesModels = new List<VenuesModel>
            {
                new VenuesModel
                {
                    CountryCode = "USA",
                    VenueType = "pop",
                    VenueName = "Test Tenant 1",
                    PostalCode = "123",
                    AdminEmail = "admin@email.com",
                    AdminPassword = "password",
                    VenueId = -1929398168
                },
                new VenuesModel
                {
                    CountryCode = "USA",
                    VenueType = "jazz",
                    VenueName = "Test Tenant 2",
                    PostalCode = "321",
                    AdminEmail = "jazzadmin@email.com",
                    AdminPassword = "password",
                    VenueId = 1032943028
                }
            };
        }

        public async Task<List<CountryModel>> GetAllCountries(int tenantId)
        {
            return Countries;
        }

        public async Task<CountryModel> GetCountry(string countryCode, int tenantId)
        {
            return Countries.Where(i => i.CountryCode.Equals(countryCode)).FirstOrDefault();
        }

        public async Task<int> AddCustomer(CustomerModel customerModel, int tenantId)
        {
            customerModel.VenueId = tenantId;
            CustomerModels.Add(customerModel);
            return customerModel.CustomerId;
        }

        public async Task<CustomerModel> GetCustomer(string email, int tenantId)
        {
            return CustomerModels.Where(i => i.Email.Equals(email)).FirstOrDefault();
        }

        public async Task<List<EventSectionModel>> GetEventSections(int eventId, int tenantId)
        {
            return EventSectionModels.Where(i => i.EventId == eventId && i.VenueId == tenantId).ToList();
        }

        public async Task<List<SectionModel>> GetSections(List<int> sectionIds, int tenantId)
        {
            return SectionModels.Where(i => sectionIds.Contains(i.SectionId) && i.VenueId == tenantId).ToList();
        }

        public async Task<SectionModel> GetSection(int sectionId, int tenantId)
        {
            return SectionModels.FirstOrDefault(i => i.VenueId == tenantId);
        }

        public async Task<int> AddTicketPurchase(TicketPurchaseModel ticketPurchaseModel, int tenantId)
        {
            ticketPurchaseModel.VenueId = tenantId;
            TicketPurchaseModels.Add(ticketPurchaseModel);
            return ticketPurchaseModel.TicketPurchaseId;
        }

        public async Task<int> GetNumberOfTicketPurchases(int tenantId)
        {
            return TicketPurchaseModels.Count(i => i.VenueId == tenantId);
        }

        public async Task<bool> AddTickets(List<TicketModel> ticketModel, int tenantId)
        {
            foreach (TicketModel tkt in ticketModel)
            {
                tkt.VenueId = tenantId;
                TicketModels.Add(tkt);
            }
            return true;
        }

        public async Task<int> GetTicketsSold(int sectionId, int eventId, int tenantId)
        {
            return TicketModels.Count(i => i.VenueId == tenantId);
        }

        public async Task<VenuesModel> GetVenueDetails(int tenantId)
        {
            return VenuesModels.FirstOrDefault(i => i.VenueId == tenantId);
        }

        public async Task<VenueTypeModel> GetVenueType(string venueType, int tenantId)
        {
            return new VenueTypeModel
            {
                Language = "en-us",
                VenueType = "pop",
                EventTypeShortNamePlural = "event short name",
                EventTypeName = "classic",
                VenueTypeName = "type 1",
                EventTypeShortName = "short name"
            };
        }

        public async Task<List<EventModel>> GetEventsForTenant(int tenantId)
        {
            return EventModels.Where(i => i.VenueId == tenantId).ToList();
        }

        public async Task<EventModel> GetEvent(int eventId, int tenantId)
        {
            return EventModels.FirstOrDefault(i => i.EventId == eventId && i.VenueId == tenantId);
        }

    }
}