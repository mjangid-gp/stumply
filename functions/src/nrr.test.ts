function calculateNrr(
  runsScored: number,
  oversFaced: number,
  runsConceded: number,
  oversBowled: number
): number {
  if (oversFaced === 0 || oversBowled === 0) return 0;
  return runsScored / oversFaced - runsConceded / oversBowled;
}

describe('NRR Calculator', () => {
  it('calculates positive NRR', () => {
    expect(calculateNrr(200, 20, 180, 20)).toBeCloseTo(1.0);
  });

  it('returns 0 for no overs', () => {
    expect(calculateNrr(0, 0, 0, 0)).toBe(0);
  });
});
