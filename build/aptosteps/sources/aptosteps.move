module aptosteps::aptosteps {
    use std::signer;
    use std::vector;
    use std::string;
    use std::error;

    // Error codes
    const ENOT_ADMIN: u64 = 0;
    const EQUEST_NOT_FOUND: u64 = 1;
    const EALREADY_JOINED: u64 = 2;
    const ESTEPS_NOT_ENOUGH: u64 = 3;

    // Struct that defines a quest
    // FIX: Removed 'has copy' ability.
    // Quest cannot be copied because its fields (string::String and vector<address>) do not have the 'copy' ability.
    struct Quest has drop, store {
        id: u64,
        name: string::String,
        step_goal: u64,
        deadline_timestamp: u64,
        completed_users: vector<address>,
        joined_users: vector<address>,
    }

    // Admin resource to store and manage quests
    struct QuestBook has key {
        quests: vector<Quest>,
        quest_count: u64,
    }

    // Resource that only deployer owns (admin)
    struct Admin has key {}

    // Initializes the module with admin privileges
    public fun init_admin(account: &signer) {
        // Assert that the Admin resource does not already exist at this address
        assert!(!exists<Admin>(signer::address_of(account)), error::already_exists(ENOT_ADMIN));

        move_to(account, Admin {});
        move_to(account, QuestBook {
            quests: vector::empty<Quest>(),
            quest_count: 0,
        });
    }

    // Helper: asserts that caller is the admin
    fun assert_admin(account: &signer) {
        assert!(exists<Admin>(signer::address_of(account)), ENOT_ADMIN);
    }

    // Creates a new walk quest
    public fun create_quest(
        admin: &signer,
        name: string::String,
        step_goal: u64,
        deadline_timestamp: u64
    ) acquires QuestBook {
        assert_admin(admin);

        let quest_book = borrow_global_mut<QuestBook>(signer::address_of(admin));
        let id = quest_book.quest_count;

        let new_quest = Quest {
            id,
            name,
            step_goal,
            deadline_timestamp,
            completed_users: vector::empty<address>(),
            joined_users: vector::empty<address>(),
        };

        vector::push_back(&mut quest_book.quests, new_quest);
        quest_book.quest_count = id + 1;
    }

    // Users join a specific quest by ID
    public fun join_quest(user: &signer, admin_address: address, quest_id: u64) acquires QuestBook {
        let quest_book = borrow_global_mut<QuestBook>(admin_address);
        let user_addr = signer::address_of(user);

        // Ensure the quest_id is valid
        assert!(quest_id < quest_book.quest_count, EQUEST_NOT_FOUND);

        let already_joined = vector::contains(
            &vector::borrow(&quest_book.quests, quest_id).joined_users,
            &user_addr
        );
        assert!(!already_joined, EALREADY_JOINED);

        vector::push_back(
            &mut vector::borrow_mut(&mut quest_book.quests, quest_id).joined_users,
            user_addr
        );
    }

    // Users submit steps to complete a quest
    public fun submit_steps(
        user: &signer,
        admin_address: address,
        quest_id: u64,
        steps: u64,
        current_time: u64
    ) acquires QuestBook {
        let user_addr = signer::address_of(user);

        // Step 1: Get a mutable reference to the QuestBook resource
        let quest_book_ref = borrow_global_mut<QuestBook>(admin_address);

        // Ensure the quest_id is valid
        assert!(quest_id < quest_book_ref.quest_count, EQUEST_NOT_FOUND);

        // Step 2: Get a mutable reference to the quest using the quest_id
        let quest = vector::borrow_mut(&mut quest_book_ref.quests, quest_id);

        // Check if user has joined this quest
        assert!(vector::contains(&quest.joined_users, &user_addr), EQUEST_NOT_FOUND);

        // Check if the steps submitted meet the goal
        assert!(steps >= quest.step_goal, ESTEPS_NOT_ENOUGH);

        // Check if the submission is before the deadline
        assert!(current_time <= quest.deadline_timestamp, error::invalid_argument(0));

        // Add user to completed_users if not already there
        if (!vector::contains(&quest.completed_users, &user_addr)) {
            vector::push_back(&mut quest.completed_users, user_addr);
        }
    }

    // Returns a list of all quest IDs.
    // Since Quest is not copyable, we return a vector of IDs instead of a reference to the full quest vector.
    #[view]
    public fun get_all_quests(admin_address: address): vector<u64> acquires QuestBook {
        let quest_book = borrow_global<QuestBook>(admin_address);
        let quest_ids = vector::empty<u64>();
        let i = 0;
        let count = vector::length(&quest_book.quests);
        while (i < count) {
            let quest_ref = vector::borrow(&quest_book.quests, i);
            vector::push_back(&mut quest_ids, quest_ref.id);
            i = i + 1;
        };
        quest_ids
    }

    // Helper function to get the total number of quests
    #[view]
    public fun get_quest_count(admin_address: address): u64 acquires QuestBook {
        borrow_global<QuestBook>(admin_address).quest_count
    }

    // Helper function to get details of a specific quest
    #[view]
    public fun get_quest_details(admin_address: address, quest_id: u64): (u64, string::String, u64, u64, vector<address>, vector<address>) acquires QuestBook {
        let quest_book = borrow_global<QuestBook>(admin_address);
        assert!(quest_id < quest_book.quest_count, EQUEST_NOT_FOUND);
        let quest = vector::borrow(&quest_book.quests, quest_id);
        (quest.id, quest.name, quest.step_goal, quest.deadline_timestamp, quest.completed_users, quest.joined_users)
    }
}