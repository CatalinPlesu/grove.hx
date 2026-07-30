# Test through production boundaries

Test every user-visible Grove behavior through real Helix and Grove's public
interface so `docs/features` remains the single executable behavior contract.
Use pure Model and Layout tests only for laws that Host polling cannot prove,
such as first-frame behavior. Do not duplicate feature scenarios or expose
private implementation.
