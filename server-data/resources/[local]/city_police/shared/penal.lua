-- The penal code: what each crime costs. months = jail time, fine = dollars (a bank bill), points = driving licence
-- points. Sent to the MDT and checked again on the server, so the page can't make up its own prices.
return {
    categories = { 'traffic', 'misdemeanor', 'felony' },

    crimes = {
        { id = 'speeding', category = 'traffic', title = 'Speeding', months = 0, fine = 250, points = 3 },
        { id = 'speeding_excessive', category = 'traffic', title = 'Excessive speeding', months = 0, fine = 750, points = 6 },
        { id = 'reckless', category = 'traffic', title = 'Reckless driving', months = 5, fine = 1000, points = 6 },
        { id = 'red_light', category = 'traffic', title = 'Running a red light', months = 0, fine = 300, points = 3 },
        { id = 'no_licence', category = 'traffic', title = 'Driving without a licence', months = 0, fine = 1500, points = 0 },
        { id = 'illegal_parking', category = 'traffic', title = 'Illegal parking', months = 0, fine = 150, points = 1 },
        { id = 'hit_and_run', category = 'traffic', title = 'Hit and run', months = 10, fine = 2500, points = 10 },
        { id = 'evading', category = 'traffic', title = 'Evading the police', months = 15, fine = 3000, points = 10 },
        { id = 'dui', category = 'traffic', title = 'Driving under the influence', months = 10, fine = 2000, points = 10 },

        { id = 'disorderly', category = 'misdemeanor', title = 'Disorderly conduct', months = 5, fine = 500, points = 0 },
        { id = 'trespassing', category = 'misdemeanor', title = 'Trespassing', months = 5, fine = 750, points = 0 },
        { id = 'resisting', category = 'misdemeanor', title = 'Resisting arrest', months = 10, fine = 1000, points = 0 },
        { id = 'obstruction', category = 'misdemeanor', title = 'Obstruction of justice', months = 10, fine = 1500, points = 0 },
        { id = 'false_report', category = 'misdemeanor', title = 'False report to the police', months = 5, fine = 1000, points = 0 },
        { id = 'harassment', category = 'misdemeanor', title = 'Harassment', months = 5, fine = 1000, points = 0 },
        { id = 'assault', category = 'misdemeanor', title = 'Assault', months = 15, fine = 2000, points = 0 },
        { id = 'vandalism', category = 'misdemeanor', title = 'Vandalism', months = 5, fine = 1000, points = 0 },
        { id = 'fishing_no_licence', category = 'misdemeanor', title = 'Fishing without a licence', months = 0, fine = 500, points = 0 },
        { id = 'petty_theft', category = 'misdemeanor', title = 'Petty theft', months = 10, fine = 1500, points = 0 },
        { id = 'drug_possession', category = 'misdemeanor', title = 'Possession of drugs', months = 10, fine = 2000, points = 0 },
        { id = 'weapon_no_licence', category = 'misdemeanor', title = 'Carrying a weapon without a licence', months = 15, fine = 3000, points = 0 },

        { id = 'vehicle_theft', category = 'felony', title = 'Grand theft auto', months = 20, fine = 4000, points = 0 },
        { id = 'armed_robbery', category = 'felony', title = 'Armed robbery', months = 30, fine = 7500, points = 0 },
        { id = 'store_robbery', category = 'felony', title = 'Store robbery', months = 25, fine = 5000, points = 0 },
        { id = 'bank_robbery', category = 'felony', title = 'Bank robbery', months = 45, fine = 15000, points = 0 },
        { id = 'burglary', category = 'felony', title = 'Burglary', months = 20, fine = 5000, points = 0 },
        { id = 'drug_trafficking', category = 'felony', title = 'Drug trafficking', months = 35, fine = 10000, points = 0 },
        { id = 'illegal_weapon', category = 'felony', title = 'Possession of an illegal weapon', months = 25, fine = 7500, points = 0 },
        { id = 'kidnapping', category = 'felony', title = 'Kidnapping', months = 35, fine = 10000, points = 0 },
        { id = 'assault_officer', category = 'felony', title = 'Assault on an officer', months = 30, fine = 7500, points = 0 },
        { id = 'attempted_murder', category = 'felony', title = 'Attempted murder', months = 45, fine = 15000, points = 0 },
        { id = 'murder', category = 'felony', title = 'Murder', months = 60, fine = 25000, points = 0 },
        { id = 'murder_officer', category = 'felony', title = 'Murder of an officer', months = 90, fine = 50000, points = 0 },
    },
}
