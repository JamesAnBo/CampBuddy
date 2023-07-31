local profiles = {}

--[[
		[''] = {
			nickname = '',
			group = '',
			zone = '',
			placeholders = {
				[''] = 000,
			};
		},
]]--

local profiles = T{
	PH = {
	-- ATTOHWA CHASM
		['Ambusher Antlion'] = {
			nickname = 'ambusher',
			group = 'chasm',
			zone = 'ATTOHWA CHASM',
			placeholders = {
				['11B'] = 976, --respawn is?
			};
		},
		['Citipati'] = {
			nickname = 'citi',
			group = 'chasm',
			zone = 'ATTOHWA CHASM',
			placeholders = {
				['10B'] = 976, --respawn is?
				['10E'] = 976, --respawn is?
				['111'] = 976, --respawn is?
			};
		},
	-- BIBIKI BAY
		['Serra'] = {
			nickname = 'serra',
			group = 'bibiki',
			zone = 'BIBIKI BAY',
			placeholders = {
				['02D'] = 346,
			};
		},
		['Intulo'] = {
			nickname = 'intulo',
			group = 'bibiki',
			zone = 'BIBIKI BAY',
			placeholders = {
				['08D'] = 346,
			};
		},
	-- BOSTAUNIEUX OUBLIETTE
		['Sewer Syrup'] = {
			nickname = 'syrup',
			group = 'sewers',
			zone = 'BOSTAUNIEUX OUBLIETTE',
			placeholders = {
				['039'] = 976,
				['03A'] = 976,
			};
		},
	-- CASTLE OZTROJA
		['Mee Deggi the Punisher'] = {
			nickname = 'deggi',
			group = 'castleo',
			zone = 'CASTLE OZTROJA',
			placeholders = {
				['056'] = 976,
				['057'] = 976
			};
		},
		['Quu Domi the Gallant'] = {
			nickname = 'domi',
			group = 'castleo',
			zone = 'CASTLE OZTROJA',
			placeholders = {
				['09B'] = 976,
				['09C'] = 976
			};
		},
	-- GIDDEUS
		['Hoo Mjuu The Torrent'] = {
			nickname = 'mjuu',
			group = 'giddeus',
			zone = 'GIDDEUS',
			['179'] = 976
		},
	-- KUFTAL TUNNEL
		['Devil Manta'] = {
			nickname = 'manta',
			group = 'angelskin',
			zone = 'KUFTAL TUNNEL',
			placeholders = {
				['005'] = 616,
			};
		},
	-- LABYRINTH OF ONZOZO
		['Lord of Onzozo'] = {
			nickname = 'loo',
			group = 'onzozo',
			zone = 'LABYRINTH OF ONZOZO',
			placeholders = {
				['042'] = 976
			};
		},
		['Ose'] = { 
			nickname = 'Ose',
			group = 'onzozo',
			zone = 'LABYRINTH OF ONZOZO',
			placeholders = { 
				['095'] = 976,
				['096'] = 976,
				['0A0'] = 976,
				['09C'] = 976,
				['09F'] = 976,
				['098'] = 976,
				['097'] = 976,
			};
		},
		['Soulstealer Skullnix'] = { 
			nickname = 'Soulstealer',
			group = 'onzozo',
			zone = 'LABYRINTH OF ONZOZO',
			placeholders = { 
				['0B5'] = 976,
				['0A1'] = 976,
			};
		},
	-- LUFAISE MEADOWS
		['Megalobugard'] = {
			nickname = 'megalo',
			group = 'lufaise',
			zone = 'LUFAISE MEADOWS',
			placeholders = {
				['0C8'] = 346,
			};
		},
	-- QUICKSAND CAVES
		['Centurio X-I'] = {
			nickname = 'centxi',
			group = 'qsc',
			zone = 'QUICKSAND CAVES',
			placeholders = {
				['035'] = 436,
			};
		},
	-- SEA SERPENT GROTTO
		['Charybdis'] = {
			nickname = 'charby',
			group = 'ssg',
			zone = 'SEA SERPENT GROTTO',
			placeholders = {
				['196'] = 976,
				['198'] = 976,
				['199'] = 976
			};
		},
	-- SOUTH GUSTABERG
		['Leaping Lizzy'] = {
			nickname = 'll',
			group = 'gusta',
			zone = 'SOUTH GUSTABERG',
			placeholders = {
				['17B'] = 346
			};
		},
	-- THE BOYAHDA TREE
		['Aquarius'] = { 
			nickname = 'Aquar',
			group = 'tree',
			zone = 'THE BOYAHDA TREE',
			placeholders = { 
				['059'] = 976,
				['05A'] = 976,
				['05B'] = 976,
				['05D'] = 976,
				['05E'] = 976,
				['05F'] = 976,
				['062'] = 976,
				['063'] = 976,
				['064'] = 976,
			};
		},
	-- THE GARDEN OF RUHMET
		['Ix\'aern'] = {
			nickname = 'ix',
			group = 'sea',
			zone = 'THE GARDEN OF RUHMET',
			placeholders = {
				['1BA'] = 60,
				['1BE'] = 60,
			}
		},
	-- VALKURM DUNES
		['Valkurm Emepror'] = {
			nickname = 've',
			group = 'dunes',
			zone = 'VALKURM DUNES',
			placeholders = {
				['14A'] = 346
			};
		},
		['Golden Bat'] = {
			nickname = 'gb',
			group = 'dunes',
			zone = 'VALKURM DUNES',
			placeholders = {
				['1CA'] = 346
			};
		},
	-- WEST RONFAURE
		['Jaggedy-Eared Jack'] = {
			nickname = 'jej',
			group = 'ronf',
			zone = 'WEST RONFAURE',
			placeholders = {
				['126'] = 346
			};
		},
	},
	NMsets = {
		['sky'] = {
			['Despot'] = 7200,
			['Faust'] = 7200,
			['Mother Globe'] = 7200,
			['Steam Cleaner'] = 7200,
			['Zipacna'] = 7200,
			['Curtana'] = 10800,
		},
	};
};

return profiles; 