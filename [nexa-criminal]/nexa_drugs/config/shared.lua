NexaDrugsConfig = {
    featureFlag = 'phase9c.drugs',
    crops = {
        weed = 'Gruene Pflanze'
    },
    recipes = {
        weed_bag = 'Abgepackte Ware'
    },
    buyers = {
        {
            buyerId = 'southside_contact',
            label = 'Southside Kontakt',
            items = { 'weed_bag' }
        },
        {
            buyerId = 'sandy_contact',
            label = 'Sandy Kontakt',
            items = { 'weed_bag' }
        }
    }
}
