// To run, navigate the shell to the containing folder and run:
// >> circom agreement_verifier.circom --r1cs --wasm --sym --c
// Move output files to the "agreement_verifier_output"

pragma circom 2.1.1;

include "../circom_library/sha256/sha256_2.circom";
include "../circom_library/comparators.circom";
include "../circom_library/gates.circom";

template CompareHash() {
    signal input secret;
    signal input salary;
    signal input hashed_salary;
    signal output out;

    component hash_function = Sha256_2();
    component is_equal = IsEqual();

    hash_function.a <== secret;
    hash_function.b <== salary;
    is_equal.in[0] <== hash_function.out;
    is_equal.in[1] <== hashed_salary;
    out <== is_equal.out;
}

template parallel VerifyAllHashes() {
    // The role-salary structure will be as follows: there are 6 total roles and 5 "spots" per role, thus
    // resulting in 30 possible roles. Any empty salary (list_of_salaries[x] == 0) is assumed to be an
    // omitted salary.
    // The roles are: DESIGNER_1, DESIGNER_2, ENGINEER_1, ENGINEER_2, MARKETING_1, MARKETING_2.
    // For example, if we have 2x desginer 2's and 3x marketing 1's salaries, we have the following salaries:
    // list_of_salaries[5] = some_salary
    // list_of_salaries[6] = some_salary
    // list_of_salaries[20] = some_salary
    // list_of_salaries[21] = some_salary
    // list_of_salaries[22] = some_salary

    // Private inputs.
    signal input secret; // What is this used for?
    signal input list_of_salaries[30];

    // Public inputs.
    signal input list_of_publicly_hashed_salaries[30];
    // TODO(michael_ershov): Add in a std_of_salaries (and the corresponding checks) as well.

    // result[x] = do_hashes_match ? 1 : 0;
    // signal result[30];
    var sum_hash = 0;
    signal output out;

    // Main logic.
    var isValid = 0;

    component hash_components[30];

    for (var i = 0; i < 30; i++) {
        hash_components[i] = CompareHash();
        hash_components[i].secret <== secret;
        hash_components[i].salary <== list_of_salaries[i];
        hash_components[i].hashed_salary <== list_of_publicly_hashed_salaries[i];
        sum_hash += hash_components[i].out;
    }

    component is_hash_equal = IsEqual();
    is_hash_equal.in[0] <== 30;
    is_hash_equal.in[1] <== sum_hash;
    out <== is_hash_equal.out;
}

template VerifyAverageSalary() {
    // Private inputs.
    signal input list_of_salaries[30];

    // Public inputs.
    signal input average_of_salaries[6];

    signal output out;

    var true_salary_averages[6]; 
    var role_capacity = 5; // This should not change.
    for (var roles = 0; roles < 6; roles++) {
        true_salary_averages[roles] = 0;
        for (var person = 0; person < role_capacity; person++) {
            true_salary_averages[roles] += list_of_salaries[roles*role_capacity + person];
        }
        true_salary_averages[roles] /= role_capacity;
    }

    var truth_counter = 0;
    component are_averages_equal_components[6] ;
    for (var i = 0; i < 6; i++) {
        are_averages_equal_components[i] = IsEqual();
        are_averages_equal_components[i].in[0] <== true_salary_averages[i];
        are_averages_equal_components[i].in[1] <== average_of_salaries[i];
        truth_counter += are_averages_equal_components[i].out;
    }

    component final_comparator = IsEqual();
    final_comparator.in[0] <== 6;
    final_comparator.in[1] <== truth_counter;
    out <== final_comparator.out;
}

template verifyHashAndAverageSalary() {
    // Private inputs
    signal input secret; // What is this used for?
    signal input list_of_salaries[30];

    // Public inputs
    signal input list_of_publicly_hashed_salaries[30];
    signal input average_of_salaries[6];

    // outputs
    signal output isValidHashAndVerification;

    component hash_verification = parallel VerifyAllHashes();
    hash_verification.secret <== secret;
    hash_verification.list_of_salaries <== list_of_salaries;
    hash_verification.list_of_publicly_hashed_salaries <== list_of_publicly_hashed_salaries;

    component average_verification = VerifyAverageSalary();
    average_verification.list_of_salaries <== list_of_salaries;
    average_verification.average_of_salaries <== average_of_salaries;

    component finalVerification = AND();
    finalVerification.a <== hash_verification.out;
    finalVerification.b <== average_verification.out;
    isValidHashAndVerification <== finalVerification.out;
}

component main{public [list_of_publicly_hashed_salaries, average_of_salaries]} = verifyHashAndAverageSalary();