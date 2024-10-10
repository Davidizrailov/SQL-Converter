import java.util.List;

public class LoanEligibilityChecker {

    private static final List<String> HIGH_RISK_LOCATIONS = List.of("CityA", "CityB", "CityC");

    public String checkEligibility(Applicant applicant, Loan loan) {
        
        if (applicant.getAge() < 18) {
            return "Applicant is underaged";
        }

        
        if (loan.getType().equals("Personal") && applicant.getCreditScore() < 600) {
            return "Credit score is too low for personal loan";
        } else if (loan.getType().equals("Mortgage") && applicant.getCreditScore() < 700) {
            return "Credit score is too low for mortgage loan";
        }

        
        if (loan.getType().equals("Personal") && applicant.getIncome() < 30000) {
            return "Income too low for personal loan";
        } else if (loan.getType().equals("Mortgage") && applicant.getIncome() < 50000) {
            return "Income too low for mortgage loan";
        }

        
        if (loan.getAmount() > 100000 && applicant.getCreditScore() < 750) {
            return "Loan amount too high for credit score";
        }

        
        if (HIGH_RISK_LOCATIONS.contains(applicant.getAddress().getCity())) {
            return "Loan application from high-risk location";
        }

        
        if (loan.getType().equals("Business") 
            && applicant.getCreditScore() >= 650 
            && applicant.getIncome() > 100000 
            && !HIGH_RISK_LOCATIONS.contains(applicant.getAddress().getCity())) {
            return "Eligible for business loan";
        }

        
        if (applicant.getCreditScore() < 650 && loan.getAmount() > 50000) {
            return "Credit score and loan amount do not match eligibility criteria";
        }

        return "Eligible for loan";
    }
    
    
    static class Applicant {
        private int age;
        private int creditScore;
        private double income;
        private Address address;

        
        public int getAge() { return age; }
        public int getCreditScore() { return creditScore; }
        public double getIncome() { return income; }
        public Address getAddress() { return address; }
    }

    
    static class Loan {
        private String type;
        private double amount;

        
        public String getType() { return type; }
        public double getAmount() { return amount; }
    }

    
    static class Address {
        private String city;

        
        public String getCity() { return city; }
    }
}
