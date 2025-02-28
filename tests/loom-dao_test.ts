import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure can create valid proposal with membership",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    // First mint membership NFT
    let block = chain.mineBlock([
      Tx.contractCall("loom-membership", "mint", 
        [types.principal(wallet_1.address)], 
        accounts.get("deployer")!.address)
    ]);
    
    block = chain.mineBlock([
      Tx.contractCall("loom-dao", "create-proposal", 
        ["Test Proposal", "Test Description", types.uint(1000)], 
        wallet_1.address)
    ]);
    
    assertEquals(block.receipts[0].result.expectOk(), "1");
  },
});

Clarinet.test({
  name: "Ensure weighted voting works correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    const wallet_2 = accounts.get("wallet_2")!;
    
    // Mint tokens for voting
    let block = chain.mineBlock([
      Tx.contractCall("loom-token", "mint", 
        [types.uint(2000), types.principal(wallet_1.address)], 
        accounts.get("deployer")!.address),
      Tx.contractCall("loom-token", "mint", 
        [types.uint(1000), types.principal(wallet_2.address)], 
        accounts.get("deployer")!.address)
    ]);
    
    // Create proposal and vote
    block = chain.mineBlock([
      Tx.contractCall("loom-dao", "vote", 
        [types.uint(1), types.bool(true)],
        wallet_1.address),
      Tx.contractCall("loom-dao", "vote", 
        [types.uint(1), types.bool(false)],
        wallet_2.address)
    ]);
    
    const proposal = chain.callReadOnlyFn(
      "loom-dao",
      "get-proposal",
      [types.uint(1)],
      wallet_1.address
    );
    
    assertEquals(proposal.result.expectSome().votes_for, 2000);
    assertEquals(proposal.result.expectSome().votes_against, 1000);
  },
});
