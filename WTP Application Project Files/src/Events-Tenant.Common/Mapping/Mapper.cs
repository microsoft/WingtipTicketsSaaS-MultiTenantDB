using System;
using System.Net;
using Events_Tenant.Common.Models;
using Events_TenantUserApp.EF.CatalogDB;
using Events_TenantUserApp.EF.TenantsDB;

namespace Events_Tenant.Common.Mapping
{
    public static class Mapper
    {
        #region Entity To Model Mapping

        public static TenantModel ToTenantModel(this Tenants tenantEntity)
        {
            string tenantIdInString = BitConverter.ToString(tenantEntity.TenantId);
            tenantIdInString = tenantIdInString.Replace("-", "");

            return new TenantModel
            {
                ServicePlan = tenantEntity.ServicePlan,
                TenantId = ConvertByteKeyIntoInt(tenantEntity.TenantId),
                TenantName = tenantEntity.TenantName.ToLower().Replace(" ", ""),
                TenantIdInString = tenantIdInString
            };
        }

        public static CountryModel ToCountryModel(this Countries country)
        {
            return new CountryModel
            {
                CountryCode = country.CountryCode.Trim(),
                Language = country.Language.Trim(),
                CountryName = country.CountryName.Trim()
            };
        }

        public static CustomerModel ToCustomerModel(this Customers customer)
        {
            return new CustomerModel
            {
                FirstName = customer.FirstName,
                Email = customer.Email,
                PostalCode = customer.PostalCode,
                LastName = customer.LastName,
                CountryCode = customer.CountryCode,
                CustomerId = customer.CustomerId,
                VenueId = customer.VenueId,
                RowVersion = customer.RowVersion
            };
        }

        public static EventSectionModel ToEventSectionModel(this EventSections eventsection)
        {
            return new EventSectionModel
            {
                EventId = eventsection.EventId,
                Price = eventsection.Price,
                SectionId = eventsection.SectionId,
                VenueId = eventsection.VenueId,
                RowVersion = eventsection.RowVersion
            };
        }

        public static EventModel ToEventModel(this Events eventEntity)
        {
            return new EventModel
            {
                Date = eventEntity.Date,
                EventId = eventEntity.EventId,
                EventName = eventEntity.EventName.Trim(),
                SubTitle = eventEntity.Subtitle.Trim(),
                VenueId = eventEntity.VenueId,
                RowVersion = eventEntity.RowVersion
            };
        }

        public static SectionModel ToSectionModel(this Sections section)
        {
            return new SectionModel
            {
                SectionId = section.SectionId,
                SeatsPerRow = section.SeatsPerRow,
                SectionName = section.SectionName,
                SeatRows = section.SeatRows,
                StandardPrice = section.StandardPrice,
                VenueId = section.VenueId,
                RowVersion = section.RowVersion
            };
        }

        public static VenuesModel ToVenueModel(this Venues venueModel)
        {
            return new VenuesModel
            {
                VenueName = venueModel.VenueName.Trim(),
                AdminEmail = venueModel.AdminEmail.Trim(),
                AdminPassword = venueModel.AdminPassword,
                CountryCode = venueModel.CountryCode.Trim(),
                PostalCode = venueModel.PostalCode,
                VenueType = venueModel.VenueType.Trim(),
                VenueId = venueModel.VenueId,
                RowVersion = venueModel.RowVersion
            };
        }

        public static VenueTypeModel ToVenueTypeModel(this VenueTypes venueType)
        {
            return new VenueTypeModel
            {
                VenueType = venueType.VenueType.Trim(),
                EventTypeName = venueType.EventTypeName.Trim(),
                EventTypeShortName = venueType.EventTypeShortName.Trim(),
                EventTypeShortNamePlural = venueType.EventTypeShortNamePlural.Trim(),
                Language = venueType.Language.Trim(),
                VenueTypeName = venueType.VenueTypeName.Trim()
            };
        }

        #endregion

        #region Model to Entity Mapping

        public static Customers ToCustomersEntity(this CustomerModel customeModel)
        {
            return new Customers
            {
                CountryCode = customeModel.CountryCode,
                Email = customeModel.Email,
                FirstName = customeModel.FirstName,
                LastName = customeModel.LastName,
                PostalCode = customeModel.PostalCode,
                VenueId = customeModel.VenueId,
                RowVersion = customeModel.RowVersion
            };
        }

        public static TicketPurchases ToTicketPurchasesEntity(this TicketPurchaseModel ticketPurchaseModel)
        {
            //password not required to save demo friction
            return new TicketPurchases
            {
                CustomerId = ticketPurchaseModel.CustomerId,
                PurchaseDate = DateTime.Now,
                PurchaseTotal = ticketPurchaseModel.PurchaseTotal,
                VenueId = ticketPurchaseModel.VenueId,
                RowVersion = ticketPurchaseModel.RowVersion
            };
        }

        public static Tickets ToTicketsEntity(this TicketModel ticketModel)
        {
            return new Tickets
            {
                TicketPurchaseId = ticketModel.TicketPurchaseId,
                SectionId = ticketModel.SectionId,
                EventId = ticketModel.EventId,
                RowNumber = ticketModel.RowNumber,
                SeatNumber = ticketModel.SeatNumber,
                VenueId = ticketModel.VenueId
            };
        }

        #endregion

        #region Private methods

        /// <summary>
        /// Converts the byte key into int.
        /// </summary>
        /// <param name="key">The key.</param>
        /// <returns></returns>
        private static int ConvertByteKeyIntoInt(byte[] key)
        {
            // Make a copy of the normalized array
            byte[] denormalized = new byte[key.Length];

            key.CopyTo(denormalized, 0);

            // Flip the last bit and cast it to an integer
            denormalized[0] ^= 0x80;

            return IPAddress.HostToNetworkOrder(BitConverter.ToInt32(denormalized, 0));
        }

        #endregion
    }
}
