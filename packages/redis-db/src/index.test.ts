import { expect } from 'chai';
import client from './index';

describe('Redis DB package', () => {
  it('exports a connected client instance', () => {
    expect(client).to.be.ok;
  });
}); 