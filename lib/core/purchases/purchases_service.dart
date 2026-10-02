// Wave 8b: in-app purchases, the product ids and the entitlements live in
// mobile_kit (mobile-template); this path stays so existing imports keep
// working (a shim until 8c). SpoRand sells the default catalog
// (`ProductCatalog.standard`: remove_ads, premium_monthly, premium_yearly;
// premium includes no_ads). Entitlements come only from the server.
export 'package:mobile_kit/mobile_kit.dart'
    show
        EntitlementDef,
        EntitlementIds,
        Entitlements,
        FakePurchasesService,
        PaywallPackage,
        PaywallProduct,
        ProductCatalog,
        ProductDef,
        ProductIds,
        ProductKind,
        PurchaseCancelled,
        PurchaseFailed,
        PurchaseOutcome,
        PurchasePending,
        PurchaseSucceeded,
        PurchasesService,
        RevenueCatIds,
        ensurePurchasesUser;
