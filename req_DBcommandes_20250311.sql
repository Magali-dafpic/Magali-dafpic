
--greta PCM 507
-- une ligne par commande

--DECLARE @param_1 int = 2024
--declare @Param_2 int = 28567
-- 20250123 MMA : modif TCommande_exercice pour prendre en compte les avoirs dans le montant facturé ex et le montant réglé ex.
-- 20250128 MMA : prendre en compte tous les cas de couverture de facture (couvrant plusieurs lignes et/ou plusieurs échéances)
-- 20250211 MMA : transformation sous-requête en jointure dans #Fac_mono_ech + ajout d'une table temp #TCommande_echeances pour pouvoir afficher les mtt ech même si pas de facture sur la commande.
-- 20250303 MMA : suppression #TCommande_echeances et ajout d'un union dans #TCommande_exercice pour traiter le cas des échéances non facturées. + ajout libellé catégorie client et catégorie tiers + ajout colonne modalité app
-- 20250311 MMA : affichage du code Greta même si param2 non saisi

 --liste des factures portant sur plusieurs échéances et la même ligne de commande
SELECT distinct FAC.PIC_SPIECE, PIECE_LIGNE.PCL_SPIECELIGNE, count(PIECE_LIGNE_ECHEANCEFACTU.PLE_SPIECE_LIGNE_ECHEANCEFACTU) as nbEch
INTO #Fac_multi_ech
FROM PIECE_LIGNE_ECHEANCEFACTU with (nolock) 
    LEFT JOIN PIECE_LIGNE with (nolock) on PIECE_LIGNE.PCL_SPIECELIGNE = PIECE_LIGNE_ECHEANCEFACTU.PLE_SPIECE_LIGNEFACTU
    LEFT JOIN PIECE FAC with (nolock) on PIECE_LIGNE.PCL_SPIECE = FAC.PIC_SPIECE
    -- obligé de mettre le lien avec la commande pour éliminer toutes les commandes basculées en avenant (les liens éch-fact sont 
    -- dédoublés à chaque avenant)
    LEFT JOIN PIECE_LIGNE CDELigne with (nolock)  on CDELigne.PCL_SPIECELIGNE = PIECE_LIGNE_ECHEANCEFACTU.PLE_SPIECELIGNE 
    LEFT JOIN PIECE CDE with (nolock) on CDE.PIC_SPIECE = CDELigne.PCL_SPIECE and CDE.PIC_STYPEPIECE = 1400002
WHERE (FAC.PIC_STYPEPIECE in (1400004,1400049) or FAC.PIC_STYPEPIECE is null) -- facture, avoir ou échéance à facturer
    AND CDE.PIC_SSTATUT NOT IN (1400029,1405149) -- Différent de Basculé en avenant ou Abandonné
    AND ((@Param_2 IS NOT NULL AND FAC.PIC_SENTITE_STRUCTURE = @Param_2 )  	
		OR @Param_2 IS NULL )-- Structure
    AND 
    
      (SELECT 
            CASE 
                WHEN PLE_XDEBUT IS NOT NULL AND PLE_XDEBUT < PLE_XDATE THEN YEAR(PLE_XDEBUT)
                WHEN PLE_XDEBUT IS NOT NULL AND PLE_XDEBUT >= PLE_XDATE THEN YEAR(PLE_XDATE)
                ELSE YEAR(PLE_XDATE)
            END
        ) =@Param_1
        --and FAC.PIC_CREFERENCE = 'F_08D_24_1607'
        --AND CDE.PIC_CREFERENCe = 'C_08D_000721_03'
GROUP BY FAC.PIC_SPIECE, PIECE_LIGNE.PCL_SPIECELIGNE    -- on groupe aussi sur piece_ligne pour écarter les factures couvrant une seule échéance mais plusieurs lignes de commande
HAVING count(PIECE_LIGNE_ECHEANCEFACTU.PLE_SPIECE_LIGNE_ECHEANCEFACTU) > 1


-- liste des factures couvrant une seule échéance. On n'affiche pas PIECE_LIGNE.PCL_SPIECELIGNE et on met un distinct afin que les factures portant sur plusieurs
-- lignes n'apparaissent qu'une seule fois (pour la jointure dans la requête finale)
SELECT distinct FAC.PIC_SPIECE, PIECE_LIGNE.PCL_SPIECELIGNE, count(PIECE_LIGNE_ECHEANCEFACTU.PLE_SPIECE_LIGNE_ECHEANCEFACTU) as nbEch
INTO #Fac_mono_ech
FROM PIECE_LIGNE_ECHEANCEFACTU with (nolock) 
    LEFT JOIN PIECE_LIGNE with (nolock) on PIECE_LIGNE.PCL_SPIECELIGNE = PIECE_LIGNE_ECHEANCEFACTU.PLE_SPIECE_LIGNEFACTU
    LEFT JOIN PIECE FAC with (nolock) on PIECE_LIGNE.PCL_SPIECE = FAC.PIC_SPIECE
    -- obligé de mettre le lien avec la commande pour éliminer toutes les commandes basculées en avenant (les liens éch-fact sont 
    -- dédoublés à chaque avenant)
    LEFT JOIN PIECE_LIGNE CDELigne with (nolock)  on CDELigne.PCL_SPIECELIGNE = PIECE_LIGNE_ECHEANCEFACTU.PLE_SPIECELIGNE 
    LEFT JOIN PIECE CDE with (nolock) on CDE.PIC_SPIECE = CDELigne.PCL_SPIECE and CDE.PIC_STYPEPIECE = 1400002
	LEFT JOIN #Fac_multi_ech ON #Fac_multi_ech.PCL_SPIECELIGNE = PIECE_LIGNE.PCL_SPIECELIGNE
	
WHERE (FAC.PIC_STYPEPIECE in (1400004,1400049) or FAC.PIC_STYPEPIECE is null) -- facture, avoir ou échéance à facturer
    AND CDE.PIC_SSTATUT NOT IN (1400029,1405149) -- Différent de Basculé en avenant ou Abandonné
    AND ((@Param_2 IS NOT NULL AND FAC.PIC_SENTITE_STRUCTURE = @Param_2 )  	
		OR @Param_2 IS NULL )-- Structure
    AND 
    
      (SELECT 
            CASE 
                WHEN PLE_XDEBUT IS NOT NULL AND PLE_XDEBUT < PLE_XDATE THEN YEAR(PLE_XDEBUT)
                WHEN PLE_XDEBUT IS NOT NULL AND PLE_XDEBUT >= PLE_XDATE THEN YEAR(PLE_XDATE)
                ELSE YEAR(PLE_XDATE)
            END
        ) =@Param_1
    -- la sous requête ci-dessous ne fonctionne pas, obligée de remplacer par une jointure et une condition is null
	--AND ( PIECE_LIGNE.PCL_SPIECELIGNE)  NOT IN (SELECT PCL_SPIECELIGNE FROM #Fac_multi_ech)     -- on filtre sur spiece_ligne et pas sur spiece car on peut avoir des factures qui couvrent plusieurs lignes dont certaines avec une échéance et d'autre avec plusieurs échéances
	AND #Fac_multi_ech.PCL_SPIECELIGNE is null
        --and FAC.PIC_CREFERENCE = 'F_08D_24_1607'
       --AND CDE.PIC_CREFERENCe = 'C_08D_000721_03'
GROUP BY FAC.PIC_SPIECE, PIECE_LIGNE.PCL_SPIECELIGNE    -- on groupe aussi sur piece_ligne pour écarter les factures couvrant une seule échéance mais plusieurs lignes de commande
HAVING count(PIECE_LIGNE_ECHEANCEFACTU.PLE_SPIECE_LIGNE_ECHEANCEFACTU) = 1
  

-- liste des commandes avec mtt facturé et réglé tenant compte des factures multiéchéances et multilignes
-- le montant réglé est divisé par le nb lignes de la facture car porté par la facture et non la ligne
SELECT CDE.PIC_SPIECE, PIECE_LIGNE.PCL_SPIECELIGNE, SUM(PIECE_LIGNE_ECHEANCEFACTU.PLE_DMONTANT) as MTT_ECH_EX, SUM(PIECE_LIGNE.PCL_DTOTALTTC) + coalesce(SUM(LIGNE_avoir.PCL_DTOTALTTC), 0) as MTT_FAC_EX, SUM(FAC.PIC_DMONTANTREGLE)/nbLF.nb + coalesce(SUM(LIGNE_avoir.PCL_DTOTALTTC), 0)/nbLA.nb as MTT_REGLE_EX 
INTO #TCommande_exercice
    FROM PIECE_LIGNE_ECHEANCEFACTU with (nolock) 
    LEFT JOIN PIECE_LIGNE with (nolock) on PIECE_LIGNE.PCL_SPIECELIGNE = PIECE_LIGNE_ECHEANCEFACTU.PLE_SPIECE_LIGNEFACTU
    LEFT JOIN PIECE FAC with (nolock) on PIECE_LIGNE.PCL_SPIECE = FAC.PIC_SPIECE
    LEFT JOIN PIECE_LIGNE LIGNE_avoir with (nolock) on LIGNE_avoir.PCL_SPIECELIGNE_SRC = PIECE_LIGNE.PCL_SPIECELIGNE
    INNER JOIN #Fac_mono_ech ON PIECE_LIGNE.PCL_SPIECE = #Fac_mono_ech.PIC_SPIECE AND #Fac_mono_ech.PCL_SPIECELIGNE = PIECE_LIGNE.PCL_SPIECELIGNE
    LEFT JOIN PIECE_LIGNE CDELigne with (nolock)  on CDELigne.PCL_SPIECELIGNE = PIECE_LIGNE_ECHEANCEFACTU.PLE_SPIECELIGNE 
    LEFT JOIN PIECE CDE with (nolock) on CDE.PIC_SPIECE = CDELigne.PCL_SPIECE and CDE.PIC_STYPEPIECE = 1400002

    LEFT JOIN (-- sous req pour avoir le nombre de lignes de facture par avoir)
        SELECT Ligne_av.PCL_SPIECE, count(Ligne_av.PCL_SPIECELIGNE) as nb
        FROM PIECE_LIGNE Ligne_av
		GROUP BY Ligne_av.PCL_SPIECE
		) as nbLA
        ON nbLA.PCL_SPIECE = FAC.PIC_SPIECE
     
     LEFT JOIN (-- sous req pour avoir le nombre de lignes de facture par facture)
        SELECT Ligne_fac.PCL_SPIECE, count(Ligne_fac.PCL_SPIECELIGNE) as nb
        FROM PIECE_LIGNE Ligne_fac 
		GROUP BY Ligne_fac.PCL_SPIECE
		) as nbLF
        ON nbLF.PCL_SPIECE = FAC.PIC_SPIECE  
		
    WHERE (FAC.PIC_STYPEPIECE in (1400004,1400049) or FAC.PIC_STYPEPIECE is null) -- facture, avoir ou échéance à facturer
    AND CDE.PIC_SSTATUT NOT IN (1400029,1405149) -- Différent de Basculé en avenant ou Abandonné
    AND ((@Param_2 IS NOT NULL AND FAC.PIC_SENTITE_STRUCTURE = @Param_2 )  	
		OR @Param_2 IS NULL )-- Structure
    AND 
    
      (SELECT 
            CASE 
                WHEN PLE_XDEBUT IS NOT NULL AND PLE_XDEBUT < PLE_XDATE THEN YEAR(PLE_XDEBUT)
                WHEN PLE_XDEBUT IS NOT NULL AND PLE_XDEBUT >= PLE_XDATE THEN YEAR(PLE_XDATE)
                ELSE YEAR(PLE_XDATE)
            END
        ) =@Param_1
 
    --AND FAC.PIC_CREFERENCe = 'F_08D_24_4036'
    --AND PIECE_LIGNE.PCL_SPRODUIT = 14048
    --AND CDE.PIC_CREFERENCe = 'C_08D_000721_03'
    GROUP BY CDE.PIC_SPIECE, PIECE_LIGNE.PCL_SPIECELIGNE, nbLA.nb, nbLF.nb 

UNION

-- on divise la somme des montants des lignes par le nombre de fois que la ligne de facture est couverte par une échéance.
SELECT CDE.PIC_SPIECE, PIECE_LIGNE.PCL_SPIECELIGNE, sum(PIECE_LIGNE_ECHEANCEFACTU.PLE_DMONTANT) as MTT_ECH_EX, sum(PIECE_LIGNE.PCL_DTOTALTTC)/#Fac_multi_ech.nbEch + coalesce(sum(LIGNE_avoir.PCL_DTOTALTTC)/#Fac_multi_ech.nbEch, 0) as MTT_FAC_EX, sum(FAC.PIC_DMONTANTREGLE)/#Fac_multi_ech.nbEch/nbLF.nb + coalesce(SUM(LIGNE_avoir.PCL_DTOTALTTC)/#Fac_multi_ech.nbEch, 0)/nbLA.nb as MTT_REGLE_EX 
    FROM PIECE_LIGNE_ECHEANCEFACTU with (nolock) 
    LEFT JOIN PIECE_LIGNE with (nolock) on PIECE_LIGNE.PCL_SPIECELIGNE = PIECE_LIGNE_ECHEANCEFACTU.PLE_SPIECE_LIGNEFACTU
    LEFT JOIN PIECE FAC with (nolock) on PIECE_LIGNE.PCL_SPIECE = FAC.PIC_SPIECE
    LEFT JOIN PIECE_LIGNE LIGNE_avoir with (nolock) on LIGNE_avoir.PCL_SPIECELIGNE_SRC = PIECE_LIGNE.PCL_SPIECELIGNE
    INNER JOIN #Fac_multi_ech ON PIECE_LIGNE.PCL_SPIECE = #Fac_multi_ech.PIC_SPIECE AND #Fac_multi_ech.PCL_SPIECELIGNE = PIECE_LIGNE.PCL_SPIECELIGNE
    -- obligé de mettre le lien avec la commande pour éliminer toutes les commandes basculées en avenant (les liens éch-fact sont 
    -- dédoublés à chaque avenant)
    LEFT JOIN PIECE_LIGNE CDELigne with (nolock)  on CDELigne.PCL_SPIECELIGNE = PIECE_LIGNE_ECHEANCEFACTU.PLE_SPIECELIGNE 
    LEFT JOIN PIECE CDE with (nolock) on CDE.PIC_SPIECE = CDELigne.PCL_SPIECE and CDE.PIC_STYPEPIECE = 1400002

    LEFT JOIN (-- sous req pour avoir le nombre de lignes de facture par avoir)
        SELECT Ligne_av.PCL_SPIECE, count(Ligne_av.PCL_SPIECELIGNE) as nb
        FROM PIECE_LIGNE Ligne_av 
		GROUP BY Ligne_av.PCL_SPIECE
		) as nbLA
        ON nbLA.PCL_SPIECE = FAC.PIC_SPIECE
     
     LEFT JOIN (-- sous req pour avoir le nombre de lignes de facture par facture)
        SELECT Ligne_fac.PCL_SPIECE, count(Ligne_fac.PCL_SPIECELIGNE) as nb
        FROM PIECE_LIGNE Ligne_fac
		GROUP BY Ligne_fac.PCL_SPIECE		
		) as nbLF
        ON nbLF.PCL_SPIECE = FAC.PIC_SPIECE  
        
    WHERE (FAC.PIC_STYPEPIECE in (1400004,1400049) or FAC.PIC_STYPEPIECE is null) -- facture, avoir ou échéance à facturer
    AND CDE.PIC_SSTATUT NOT IN (1400029,1405149) -- Différent de Basculé en avenant ou Abandonné
    AND ((@Param_2 IS NOT NULL AND FAC.PIC_SENTITE_STRUCTURE = @Param_2 )  	
		OR @Param_2 IS NULL )-- Structure -- Structure
    AND 
    
      (SELECT 
            CASE 
                WHEN PLE_XDEBUT IS NOT NULL AND PLE_XDEBUT < PLE_XDATE THEN YEAR(PLE_XDEBUT)
                WHEN PLE_XDEBUT IS NOT NULL AND PLE_XDEBUT >= PLE_XDATE THEN YEAR(PLE_XDATE)
                ELSE YEAR(PLE_XDATE)
            END
        ) =@Param_1
 
    
    --AND CDE.PIC_CREFERENCe = 'C_08D_000721_03'
    GROUP BY CDE.PIC_SPIECE, PIECE_LIGNE.PCL_SPIECELIGNE, #Fac_multi_ech.nbEch,  nbLA.nb, nbLF.nb 

UNION

-- commandes non facturées
SELECT CDE.PIC_SPIECE, null, SUM(PIECE_LIGNE_ECHEANCEFACTU.PLE_DMONTANT) as MTT_ECH_EX, 0, 0 

    FROM PIECE_LIGNE_ECHEANCEFACTU with (nolock) 
        LEFT JOIN PIECE_LIGNE CDELigne with (nolock)  on CDELigne.PCL_SPIECELIGNE = PIECE_LIGNE_ECHEANCEFACTU.PLE_SPIECELIGNE 
    LEFT JOIN PIECE CDE with (nolock) on CDE.PIC_SPIECE = CDELigne.PCL_SPIECE and CDE.PIC_STYPEPIECE = 1400002
    --LEFT JOIN PIECE_LIGNE with (nolock) on PIECE_LIGNE.PCL_SPIECELIGNE = PIECE_LIGNE_ECHEANCEFACTU.PLE_SPIECE_LIGNEFACTU
    --LEFT JOIN PIECE FAC with (nolock) on PIECE_LIGNE.PCL_SPIECE = FAC.PIC_SPIECE

    
		
    WHERE PLE_SPIECE_LIGNEFACTU is null 
	AND CDE.PIC_SSTATUT NOT IN (1400029,1405149) -- Différent de Basculé en avenant ou Abandonné
	AND ((@Param_2 IS NOT NULL AND CDE.PIC_SENTITE_STRUCTURE = @Param_2 )  	
		OR @Param_2 IS NULL )-- Structure
    
    AND 
    
      (SELECT 
            CASE 
                WHEN PLE_XDEBUT IS NOT NULL AND PLE_XDEBUT < PLE_XDATE THEN YEAR(PLE_XDEBUT)
                WHEN PLE_XDEBUT IS NOT NULL AND PLE_XDEBUT >= PLE_XDATE THEN YEAR(PLE_XDATE)
                ELSE YEAR(PLE_XDATE)
            END
        ) =@Param_1
 
    --AND FAC.PIC_CREFERENCe = 'F_08D_24_4036'
    --AND PIECE_LIGNE.PCL_SPRODUIT = 14048
    --AND CDE.PIC_CREFERENCe = 'C_08D_000721_03'
    GROUP BY CDE.PIC_SPIECE

SELECT 

    (SELECT STRUCT.CCODECENTRE FROM CENTREGEST STRUCT with(nolock) WHERE STRUCT.SENTITE = CDE.PIC_SENTITE_STRUCTURE) AS CODE_STRUCTURE,
    IIF(@Param_1 IS NULL, '', CAST(@Param_1 AS VARCHAR(4))) AS ANNEE,                                                                            
    --p.PRD_SPRODUIT AS ID_PRODUIT,
	fm.FAM_CCODE										as CODE_FAMILLE,
	fm.FAM_CLIBELLE										as LIB_FAMILLE,
	f.FAM_CCODE 										as CODE_SS_FAM,
	f.FAM_CLIBELLE										as LIB_SS_FAMILLE,
   
    P.PRD_CCODE                                                     AS CODE_PRODUIT, -- Produit principal
    dbo.FctVAL_ConstantecODE(PRODUIT_FORMATION.PFO_STHEMEPRINC)	    as CODE_TYPOLOGIE_PRODUIT,
    dbo.FctVAL_ConstanteLibelle(PRODUIT_FORMATION.PFO_STHEMEPRINC)	as TYPOLOGIE_PRODUIT,
    D.CREFERENCE                                                    as ACTION,
    D.CDISPOLIB1                                                    as LIB_ACTION,
	dbo.FctVAL_ConstanteLibelle(D.SSTATUT)							as MODALITE_APP,
    LIEU.LIE_CCODE				                                    as CODE_LIEU_ACTION,
    LIEU.LIE_CLIBELLE                                                as LIEU_ACTION,
    (SELECT coalesce(count(*), 0)
    FROM VVAL_AMMON_LIENS_Inscr_Piece
    WHERE sPiece = CDE.PIC_SPIECE)                                      as NB_INS,
    --I.SINSCR                                                        as INSCRIPTION,
    CDE.PIC_CREFERENCE                                              as REF_COMMANDE,
    CDE.PIC_IVERSION                                                as VERSION,
    CDE.PIC_COBJET                                                  as LIB_COMMANDE,
    dbo.FctVAL_ConstanteLibelle(CDE.PIC_SSTATUT)                    as ETAT_COMMANDE,
    CDE.PIC_CREFINTERNE                                             as REF_INT,
    CDE.PIC_CREFEXTERNE                                             as REF_EXT,
    auteur.CNOM                                                     as AUTEUR,
    CONVERT(datetime,Date_deb.ZLDO_CVALEUR)                         as DATE_DEB,
    CONVERT(datetime,Date_fin.ZLDO_CVALEUR)                         as DATE_FIN,
    case 
        when EntrepClientLivr.CSIRET is null then '5'
        else dbo.FctVAL_ConstanteCode(EntrepClientLivr.SINFOCOMPLETAB1) + ' - ' + dbo.FctVAL_ConstanteLibelle(EntrepClientLivr.SINFOCOMPLETAB1)
    end                                                             AS CLIENT_CAT,
    isnull(EntrepClientLivr.CSIRET , '')                            AS CLIENT_SIRET,
    isnull(EntrepClientLivr.CNOME, IPClientLivr.CNOM)               AS CLIENT_NOM,
    CASE WHEN CDE.PIC_SCLIENT <> CDE.PIC_SCLIENTLIVRE THEN 'Oui'
    ELSE 'Non' END                                                  AS SUBRO,
    case 
        when EntrepClientFact.CSIRET is null then '5'
        else dbo.FctVAL_ConstanteCode(EntrepClientFact.SINFOCOMPLETAB1)  + ' - ' + dbo.FctVAL_ConstanteLibelle(EntrepClientFact.SINFOCOMPLETAB1)
    end                                                             AS TIERS_CAT,
    isnull(EntrepClientFact.CSIRET , '')                            AS TIERS_SIRET,
    isnull(EntrepClientFact.CNOME, IPClientFact.CNOM)               AS TIERS_NOM,
    CONVERT(decimal(12,2),REPLACE(MARCHE.ZLDO_CVALEUR,',','.'))     AS MONTANT_MARCHE,
    DOMACT.TEXTE1                                                   AS DOMAINE_ACT,
    CDE.PIC_DTOTALTTC                                               AS MONTANT_TOTAL,
    sum(#TCommande_exercice.MTT_ECH_EX)                             AS MONTANT_ECH_EX,
    sum(#TCommande_exercice.MTT_FAC_EX)                             AS MONTANT_FACTURE_EX,
    sum(#TCommande_exercice.MTT_REGLE_EX)                           AS MONTANT_REGLE_EX
    

FROM PIECE CDE with (nolock)
    INNER JOIN PRODUIT P with (nolock) ON CDE.PIC_SPRODUIT_PRINCIPAL = P.PRD_SPRODUIT
    LEFT JOIN FAMILLE_PRODUIT fp WITH (NOLOCK)	on P.PRD_SPRODUIT = fp.FMP_SPRODUIT --AND FMP_BFAMILLEPRINCIPALE = 1
    LEFT JOIN FAMILLE f	WITH (NOLOCK)			on fp.FMP_SFAMILLE = f.FAM_SFAMILLE 
    LEFT JOIN FAMILLE fm WITH (NOLOCK)			on fm.FAM_SFAMILLE = f.FAM_SFAMILLEMERE
    LEFT JOIN PRODUIT_FORMATION with (nolock) on P.PRD_SPRODUIT = PRODUIT_FORMATION.PFO_SPRODUIT
    LEFT JOIN (SELECT DISTINCT sPiece, FIRST_VALUE(sDispo) OVER (
        PARTITION BY sPiece ORDER BY sDispo ASC ROWS UNBOUNDED PRECEDING) as sDispo FROM VVAL_AMMON_LIENS_DISPO_PIECE) as lien_action on lien_action.sPiece = CDE.PIC_SPIECE
    LEFT JOIN DISPO D with (nolock) ON D.SDISPOSITIF = lien_action.sDispo
    LEFT JOIN LIEU WITH(NOLOCK)	on d.SLIEUFOR = LIEU.LIE_SLIEU
    LEFT JOIN dbo.PERSONNE as auteur with (nolock) ON CDE.PIC_SAUTEUR = auteur.SENTITE
    INNER JOIN ENTITE EntClientLivr ON CDE.PIC_SCLIENTLIVRE = EntClientLivr.SENTITE
    LEFT JOIN ENTREP EntrepClientLivr ON EntrepClientLivr.SENTITE = EntClientLivr.SENTITE
    LEFT JOIN PERSONNE IPClientLivr ON IPClientLivr.SENTITE = EntClientLivr.SENTITE     -- cas individuel payant
    INNER JOIN ENTITE EntClientFact ON CDE.PIC_SCLIENT = EntClientFact.SENTITE
    LEFT JOIN ENTREP EntrepClientFact ON EntrepClientFact.SENTITE = EntClientFact.SENTITE
    LEFT JOIN PERSONNE IPClientFact ON IPClientFact.SENTITE = EntClientFact.SENTITE     -- cas individuel payant
    LEFT JOIN ZONELIBREDONNEE MARCHE ON MARCHE.ZLDO_SENTITE = CDE.PIC_SPIECE and MARCHE.ZLDO_SDESCRIPTIONZONELIBRE = 43
    LEFT JOIN ZONELIBREDONNEE Date_deb ON Date_deb.ZLDO_SENTITE = CDE.PIC_SPIECE and Date_deb.ZLDO_SDESCRIPTIONZONELIBRE = 34
    LEFT JOIN ZONELIBREDONNEE Date_fin ON Date_fin.ZLDO_SENTITE = CDE.PIC_SPIECE and Date_fin.ZLDO_SDESCRIPTIONZONELIBRE = 35
    LEFT JOIN dbo.ZONELIBREDONNEE Domaine with (nolock) on Domaine.ZLDO_SENTITE = CDE.PIC_SPIECE AND Domaine.ZLDO_SDESCRIPTIONZONELIBRE = 33
    LEFT JOIN CONSTANTE DOMACT with (nolock) on DOMACT.SCONSTANTE = Domaine.ZLDO_CVALEUR
    LEFT JOIN #TCommande_exercice ON #TCommande_exercice.PIC_SPIECE = CDE.PIC_SPIECE
--	LEFT JOIN #TCommande_echeances ON #TCommande_echeances.PIC_SPIECE = CDE.PIC_SPIECE

WHERE
    CDE.IDESACTIVE = 0
    AND CDE.PIC_STYPEPIECE = 1400002    -- Commande
	AND ((@PARAM_2 IS NOT NULL AND CDE.PIC_SENTITE_STRUCTURE = @Param_2 )  	
		OR (@PARAM_2 is null and  CDE.PIC_SENTITE_STRUCTURE in (
			SELECT SENTITE FROM FctVAL_GetStructuresByUser([SUTILISATEUR])
			)
		)) -- Structure
    
    AND @Param_1 BETWEEN YEAR(Date_deb.ZLDO_CVALEUR) AND YEAR(Date_fin.ZLDO_CVALEUR)
    AND CDE.PIC_SSTATUT NOT IN (1400029,1405149) -- Différent de Basculé en avenant ou Abandonné
--AND CDE.PIC_CREFERENCe = 'C_08D_000721_03'

GROUP BY 
	CDE.PIC_SENTITE_STRUCTURE,
	fm.FAM_CCODE,
	fm.FAM_CLIBELLE,
	f.FAM_CCODE,
	f.FAM_CLIBELLE,
    P.PRD_CCODE, -- Produit principal
    PRODUIT_FORMATION.PFO_STHEMEPRINC,
    D.CREFERENCE,
    D.CDISPOLIB1,
	D.SSTATUT,
    LIEU.LIE_CCODE,
    LIEU.LIE_CLIBELLE,
    CDE.PIC_SPIECE,
    CDE.PIC_CREFERENCE,
    CDE.PIC_IVERSION,
    CDE.PIC_COBJET,
    CDE.PIC_SSTATUT,
    CDE.PIC_CREFINTERNE,
    CDE.PIC_CREFEXTERNE,
    auteur.CNOM,
    Date_deb.ZLDO_CVALEUR,
    Date_fin.ZLDO_CVALEUR,
    CDE.PIC_SCLIENT,
    EntrepClientLivr.SINFOCOMPLETAB1,
    EntrepClientLivr.CSIRET,
    CDE.PIC_SCLIENTLIVRE,
    EntrepClientLivr.CNOME, IPClientLivr.CNOM,
    EntrepClientFact.CSIRET, EntrepClientFact.SINFOCOMPLETAB1,
    EntrepClientFact.CNOME, IPClientFact.CNOM,
    MARCHE.ZLDO_CVALEUR,
    DOMACT.TEXTE1,
    CDE.PIC_DTOTALTTC 
ORDER BY P.PRD_CCODE, CDE.PIC_CREFERENCE

drop table #Fac_mono_ech
drop table #Fac_multi_ech
drop table #TCommande_exercice