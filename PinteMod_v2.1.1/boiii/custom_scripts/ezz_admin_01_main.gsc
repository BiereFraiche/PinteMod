// ============================================================
// PinteMod Core v2.1.1
// Fichier : ezz_admin_01_main.gsc
// Créé par BiereFraiche et ChatGPT
//
// Point d'entrée autonome du framework dédié Zombies.
// ============================================================

autoexec function init()
{
    level.ezz_admin_loaded = true;
    level.ezz_admin_release = "2.1.1";
    level.pintemod_core_loaded = true;
    level.pintemod_core_version = "2.1.1";

    println("^5[PinteMod]^7 Core v2.1.1 loaded");
    say("^3[PinteMod]^7 ^2v2.1.1 loaded^7");
}
