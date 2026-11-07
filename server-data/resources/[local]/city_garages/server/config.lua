return {
    -- Impound lot fee for a car left out on the street: a share of its catalogue price, kept between min and max
    depotFee = { share = 0.02, min = 250, max = 10000 },
    doorsLocked = true, -- taken-out cars start locked (the owner gets the keys)
    maxPropsBytes = 65536, -- largest vehicle properties a client may send when parking
}
