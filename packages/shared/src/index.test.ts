import { expect } from 'chai';
import { dummy } from './index.js';

describe('Shared package', () => {
  it('dummy returns correct string', () => {
    expect(dummy()).to.equal('dummy');
  });
}); 