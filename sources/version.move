module gize::version {
    use sui::object::{UID};
    use sui::tx_context::{TxContext,};
    use sui::object;
    use sui::transfer::share_object;

    use gize::proposal::AdminCap;

    const VERSION_INIT: u64 = 1;

    const ERR_WRONG_VERSION: u64 = 1001;
    const ERR_NOT_ADMIN: u64 = 1002;

    struct VERSION has drop {}

    struct Version has key, store {
        id: UID,
        version: u64,
    }

    fun init(_witness: VERSION, ctx: &mut TxContext) {
        share_object(Version {
            id: object::new(ctx),
            version: VERSION_INIT,
        })
    }

    public fun checkVersion(version: &Version, modVersion: u64) {
        assert!(modVersion == version.version, ERR_WRONG_VERSION)
    }

    public entry fun migrate(_admin: &AdminCap, ver: &mut Version, newVer: u64 ){
        assert!(newVer > ver.version, ERR_WRONG_VERSION);
        ver.version = newVer
    }

    #[test_only]
    public fun versionForTest(ctx: &mut TxContext): Version {
        Version {
            id:  object::new(ctx),
            version: VERSION_INIT,
        }
    }

    #[test_only]
    public fun initForTest(ctx: &mut TxContext) {
        init(VERSION {}, ctx);
    }

    #[test_only]
    public fun destroyForTest(version: Version) {
       let Version {
            id,
            version: _version,
        } = version;

        object::delete(id);
    }
}
