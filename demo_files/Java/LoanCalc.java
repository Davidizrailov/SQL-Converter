package LoanCalculator;
/*
Author : MUHAMAD ASHRAFF BIN OTHMAN
         52213120560
*/
public class Loan {
    
    //DATA MEMBERS
    double interestRate;
    int years;
    double loanAmount;
    
    public Loan(){
        this(0.0,0,0.0);
    }//DEFAULT CONSTRUCTOR

    public Loan(double interestRate, int years, double loanAmount){
        this.interestRate = interestRate;
        this.years = years;
        this.loanAmount = loanAmount;
    }//CONSTRUCTOR WITH PARAMETER

    public double getInterestRate() {
        return interestRate;
    }//END GETTER

    public void setInterestRate(double interestRate) {
        this.interestRate = interestRate;
    }//END SETTER

    public int getYears() {
        return years;
    }//END GETTER

    public void setYears(int years) {
        this.years = years;
    }//END SETTER

    public double getLoanAmount() {
        return loanAmount;
    }//END GETTER

    public void setLoanAmount(double loanAmount) {
        this.loanAmount = loanAmount;
    }//END SETTER
    
    //TO CALCULATE MONTHLY PAYMENT WITH INTEREST
    public double monthlyPayment(){
        int noMonth = 12*years;
        double interestperMonth = (interestRate/100) / 12 ;
        double a = (loanAmount*interestperMonth);
        double b = (Math.pow(1+interestperMonth, noMonth));
        double c = (b-1);
        return a*b/c;
    }//END METHOD monthlyPayment

    //TO CALCULATE TOTAL PAYMENT WITH INTEREST
    public double totalPayment(){
        double totalPayment = monthlyPayment()*(12*years);
     return totalPayment;
    }//END METHOD totalPayment
    
    public double totalInterest(){
        double totalInterest = totalPayment()-loanAmount;
        return totalInterest;
    }//END METHOD totalInterest

}//END CLASS
