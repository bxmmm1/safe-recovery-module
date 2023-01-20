# Safe recovery module

More info:
https://forum.gnosis-safe.io/t/social-recovery-module/2117/5

## How to activate recovery:

1. Go to safe web app
2. Go to `apps` 
3. Click Add custom app
4. 
<img src="https://europe1.discourse-cdn.com/standard20/uploads/gnosis_safe/optimized/2X/f/fde5e325c2e22bfb7f16e684a68d54f3f28fd027_2_523x500.png">

Now the module is activated.

5. From safe, create a transaction to that module and call `addRecovery`
`addRecovery` takes 3 parameters (recoveryAddress, recoveryDate, recoveryType)
RecoveryAddress - Address to where we transfer the ownership of the safe
RecoveryType - If value is 0 the selected mode is 'Trigger transfer ownership if safe did not have any new transactions for x seconds' 
RecoveryType - If value is 1 the selected mode is 'Trigger after x timestamp' 

RecoveryDate - Based on `RecoveryType` it is either seconds, or timestamp (in seconds)
For timestamp value check https://www.epochconverter.com/

6. After executing this transaction safe is now in 'recovery mode'
7. If the transfer ownership condition is met, safe ownership is not transferred right away. It has a timelock period of 10 days.
8. If safe owner doesn't cancel ownership transfer after it has been initiated, ownership is finally transferred after timelock passes.

## Q&A:
1. Can this module steal tokens/nft's/eth from my safe?
<br>
No, Module does not have permissions to take money from safe.
2. Can this module steal safe ownership
<br>
No, safe ownership is only transferred to a predefined recovery address. 


## Usage
```
forge install
```

## Run tests
```
forge test
```