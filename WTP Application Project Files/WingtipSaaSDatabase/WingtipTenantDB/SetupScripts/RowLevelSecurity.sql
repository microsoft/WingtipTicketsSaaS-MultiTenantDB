-- separate schema to organize RLS objects 
CREATE SCHEMA rls
GO

CREATE FUNCTION rls.fn_tenantAccessPredicate(@TenantId int)     
    RETURNS TABLE     
    WITH SCHEMABINDING
AS
    RETURN SELECT 1 AS fn_accessResult          
        WHERE DATABASE_PRINCIPAL_ID() = DATABASE_PRINCIPAL_ID('dbo')
        AND CAST(SESSION_CONTEXT(N'TenantId') AS int) = @TenantId
GO

CREATE SECURITY POLICY rls.tenantAccessPolicy

	ADD FILTER PREDICATE rls.fn_tenantAccessPredicate(TenantId) ON [dbo].[Countries],
	ADD BLOCK  PREDICATE rls.fn_tenantAccessPredicate(TenantId) ON [dbo].[Countries],

	ADD FILTER PREDICATE rls.fn_tenantAccessPredicate(TenantId) ON [dbo].[Customers],
	ADD BLOCK  PREDICATE rls.fn_tenantAccessPredicate(TenantId) ON [dbo].[Customers],

	ADD FILTER PREDICATE rls.fn_tenantAccessPredicate(TenantId) ON [dbo].[Events],
	ADD BLOCK  PREDICATE rls.fn_tenantAccessPredicate(TenantId) ON [dbo].[Events],

	ADD FILTER PREDICATE rls.fn_tenantAccessPredicate(TenantId) ON [dbo].[EventSections],
	ADD BLOCK  PREDICATE rls.fn_tenantAccessPredicate(TenantId) ON [dbo].[EventSections],

	ADD FILTER PREDICATE rls.fn_tenantAccessPredicate(TenantId) ON [dbo].[Sections],
	ADD BLOCK  PREDICATE rls.fn_tenantAccessPredicate(TenantId) ON [dbo].[Sections],

	ADD FILTER PREDICATE rls.fn_tenantAccessPredicate(TenantId) ON [dbo].[TicketPurchases],
	ADD BLOCK  PREDICATE rls.fn_tenantAccessPredicate(TenantId) ON [dbo].[TicketPurchases],

	ADD FILTER PREDICATE rls.fn_tenantAccessPredicate(TenantId) ON [dbo].[Tickets],
	ADD BLOCK  PREDICATE rls.fn_tenantAccessPredicate(TenantId) ON [dbo].[Tickets],

	ADD FILTER PREDICATE rls.fn_tenantAccessPredicate(TenantId) ON [dbo].[Venues],
	ADD BLOCK  PREDICATE rls.fn_tenantAccessPredicate(TenantId) ON [dbo].[Venues],

	ADD FILTER PREDICATE rls.fn_tenantAccessPredicate(TenantId) ON [dbo].[VenueTypes],
	ADD BLOCK  PREDICATE rls.fn_tenantAccessPredicate(TenantId) ON [dbo].[VenueTypes]

GO