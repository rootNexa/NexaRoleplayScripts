# nexa_properties

Server-authoritative property foundation for property types, definitions, instances, ownership, sales, leases, rent, residents, storage links, wardrobes, garages, furniture metadata, admin actions and creator lifecycle.

No UI is included. Money movement must go through `nexa_economy`, inventory storage through `nexa_inventory`, and vehicle storage through `nexa_garages`.

Sales, lease and rent APIs expose quotes, buy/sell, lease creation/termination, rent payment, due processing and overdue marking. The foundation records the economy dependency and keeps money mutation outside this resource.

Storage, wardrobe and garage APIs resolve server-owned links only. Storage access is prepared for `nexa_inventory`, garages call `nexa_garages`, and wardrobe access validates the property permission boundary.
