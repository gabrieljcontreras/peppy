package com.peppy.app.core.data

data class PeptideInfo(
    val name: String,
    val category: String,
    val commonDose: String? = null
)

val commonPeptides = listOf(
    // GLP-1 Agonists
    PeptideInfo("Semaglutide", "GLP-1", "0.25-2.4mg weekly"),
    PeptideInfo("Tirzepatide", "GLP-1/GIP", "2.5-15mg weekly"),
    PeptideInfo("Retatrutide", "GLP-1/GIP/Glucagon", "1-12mg weekly"),
    PeptideInfo("Liraglutide", "GLP-1", "0.6-3mg daily"),
    PeptideInfo("Dulaglutide", "GLP-1", "0.75-4.5mg weekly"),
    PeptideInfo("Exenatide", "GLP-1", "5-10mcg twice daily"),
    PeptideInfo("Lixisenatide", "GLP-1", "10-20mcg daily"),
    PeptideInfo("Albiglutide", "GLP-1", "30-50mg weekly"),
    PeptideInfo("Cagrilintide", "Amylin", "2.4mg weekly"),
    PeptideInfo("Survodutide", "GLP-1/Glucagon", "0.6-6mg weekly"),

    // Growth Hormone Secretagogues
    PeptideInfo("Ipamorelin", "GHRP", "200-300mcg 2-3x daily"),
    PeptideInfo("CJC-1295", "GHRH", "1-2mg weekly"),
    PeptideInfo("CJC-1295 DAC", "GHRH", "2mg weekly"),
    PeptideInfo("Tesamorelin", "GHRH", "2mg daily"),
    PeptideInfo("Sermorelin", "GHRH", "200-500mcg daily"),
    PeptideInfo("GHRP-2", "GHRP", "100-300mcg 2-3x daily"),
    PeptideInfo("GHRP-6", "GHRP", "100-300mcg 2-3x daily"),
    PeptideInfo("Hexarelin", "GHRP", "200mcg 2-3x daily"),
    PeptideInfo("MK-677 (Ibutamoren)", "GHS", "10-25mg daily"),

    // Healing & Recovery
    PeptideInfo("BPC-157", "Healing", "250-500mcg 1-2x daily"),
    PeptideInfo("TB-500 (Thymosin Beta-4)", "Healing", "2-5mg weekly"),
    PeptideInfo("Thymosin Alpha-1", "Immune", "1.6mg 2x weekly"),
    PeptideInfo("GHK-Cu", "Healing", "1-2mg daily"),
    PeptideInfo("Pentadecapeptide", "Healing", "250-500mcg daily"),
    PeptideInfo("AOD-9604", "Fat Loss", "300mcg daily"),

    // Melanocortin Peptides
    PeptideInfo("Melanotan II", "Melanocortin", "0.25-1mg daily"),
    PeptideInfo("PT-141 (Bremelanotide)", "Melanocortin", "1-2mg as needed"),
    PeptideInfo("Melanotan I (Afamelanotide)", "Melanocortin", "1mg daily"),

    // Cognitive & Neuroprotective
    PeptideInfo("Semax", "Nootropic", "200-600mcg daily"),
    PeptideInfo("Selank", "Nootropic", "250-500mcg daily"),
    PeptideInfo("Dihexa", "Nootropic", "10-20mg daily"),
    PeptideInfo("P21", "Nootropic", "1-2mg daily"),
    PeptideInfo("Cerebrolysin", "Nootropic", "5-10ml daily"),
    PeptideInfo("NA-Semax", "Nootropic", "200-600mcg daily"),
    PeptideInfo("NA-Selank", "Nootropic", "250-500mcg daily"),

    // Insulin & Metabolic
    PeptideInfo("Insulin (Humalog)", "Insulin", "variable"),
    PeptideInfo("Insulin (Novolog)", "Insulin", "variable"),
    PeptideInfo("Insulin (Lantus)", "Insulin", "variable"),
    PeptideInfo("IGF-1 LR3", "Growth Factor", "20-100mcg daily"),
    PeptideInfo("IGF-1 DES", "Growth Factor", "50-150mcg pre-workout"),
    PeptideInfo("MGF (Mechano Growth Factor)", "Growth Factor", "100-200mcg post-workout"),
    PeptideInfo("PEG-MGF", "Growth Factor", "200mcg 2-3x weekly"),

    // Antimicrobial & Immune
    PeptideInfo("LL-37", "Antimicrobial", "100mcg daily"),
    PeptideInfo("Thymalin", "Immune", "10mg daily"),
    PeptideInfo("Epithalon", "Anti-aging", "5-10mg daily"),

    // Other Research Peptides
    PeptideInfo("DSIP (Delta Sleep)", "Sleep", "100-300mcg before bed"),
    PeptideInfo("Epitalon", "Anti-aging", "5-10mg daily"),
    PeptideInfo("Follistatin", "Myostatin Inhibitor", "100mcg daily"),
    PeptideInfo("ACE-031", "Myostatin Inhibitor", "research"),
    PeptideInfo("FTPP (Adipotide)", "Fat Loss", "research"),
    PeptideInfo("Kisspeptin", "Hormone", "research"),
    PeptideInfo("GnRH (Gonadorelin)", "Hormone", "100-200mcg 2-3x weekly"),
    PeptideInfo("Oxytocin", "Hormone", "10-40 IU intranasal"),
    PeptideInfo("Vasopressin", "Hormone", "research"),

    // Cosmetic
    PeptideInfo("Argireline", "Cosmetic", "topical"),
    PeptideInfo("Matrixyl", "Cosmetic", "topical"),
    PeptideInfo("Copper Peptides", "Cosmetic", "topical"),
    PeptideInfo("Palmitoyl Pentapeptide", "Cosmetic", "topical"),

    // Less Common / Newer
    PeptideInfo("Tesamorelin", "GHRH", "2mg daily"),
    PeptideInfo("Macimorelin", "GHRH", "diagnostic"),
    PeptideInfo("Pegvisomant", "GH Antagonist", "10-30mg daily"),
    PeptideInfo("Setmelanotide", "Melanocortin", "2-3mg daily"),
    PeptideInfo("Vosoritide", "CNP Analog", "research")
)

val peptideNames: List<String> = commonPeptides.map { it.name }
