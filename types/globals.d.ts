import type { expect as chaiExpect } from 'chai';
import type * as sinonType from 'sinon';

declare global {
  const expect: typeof chaiExpect;
  const sinon: typeof sinonType;
}

export {}; 