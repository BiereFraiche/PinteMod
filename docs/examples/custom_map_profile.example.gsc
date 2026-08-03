// Documentation example only — NOT loaded automatically by PinteMod.
// Keep runtime GSC files in boiii/custom_scripts/. This file intentionally
// contains no autoexec function.

#namespace my_custom_map_pintemod_profile;

#using custom_scripts\ezz_admin_map_audit;

function register_my_custom_map_profile()
{
    profile = SpawnStruct();

    // Required stable map code returned by the BOIII mapname dvar.
    profile.map_id = "zm_my_custom_map";
    profile.name = "My Custom Zombies Map";
    profile.profile = "CUSTOM_DECLARED";

    // Use conservative states. Do not write SUPPORTED/VALIDATED unless tested.
    profile.power = "SUPPORTED";
    profile.pap = "PARTIAL_CUSTOM_SEQUENCE";
    profile.passages = "SUPPORTED_STANDARD_ONLY";
    profile.music = "SUPPORTED";
    profile.events = "LIMITED";
    profile.bosses = "CUSTOM_BOSS_NAME";
    profile.dog_rounds = "NOT_DECLARED";
    profile.special_weapons = "CUSTOM_WEAPON_A, CUSTOM_WEAPON_B";

    // EE records remain diagnostic until the native detector is validated.
    profile.ee_profile = "DECLARED";
    profile.ee_state = "DIAGNOSTIC";

    profile.spawn_late_join = "SUPPORTED";
    profile.limitations = "Describe untested quest steps or unsupported systems";

    return ezz_admin_map_audit::register_custom_map_profile(profile);
}

// Call register_my_custom_map_profile() from the custom map's own initialized
// runtime script after PinteMod modules are available. Do not copy this example
// into boiii/custom_scripts unchanged.
