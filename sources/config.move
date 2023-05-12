module gize::config {
    friend gize::proposal;

    use sui::object::UID;
    use sui::tx_context::{TxContext, sender};
    use sui::transfer::public_transfer;
    use sui::object;
    use sui::transfer;

    const ERR_INVALID_ADMIN: u64 = 1001;

    struct CONFIG has drop {}

    struct AdminCap has key, store {
        id: UID
    }

    fun init(_witness: CONFIG, ctx: &mut TxContext) {
        let sender = sender(ctx);
        assert!(sender == @dao_admin, ERR_INVALID_ADMIN);
        public_transfer(AdminCap { id: object::new(ctx) }, @dao_admin);
    }

    public fun change_admin(adminCap: AdminCap, to: address) {
        transfer::public_transfer(adminCap, to);
    }
}
