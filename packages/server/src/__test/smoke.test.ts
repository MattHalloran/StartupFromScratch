import request from 'supertest';
import { expect } from 'chai';
import app from '../index';

describe('SSR Smoke Test', () => {
  it('GET / returns rendered HTML with dummy SSO meta and Home Page', async () => {
    const res = await request(app).get('/');
    expect(res.status).to.equal(200);
    expect(res.headers['content-type']).to.match(/html/);
    expect(res.text).to.include('<meta name="sso-client-id" content="dummy-client-id"');
    expect(res.text).to.include('<h2>Home Page</h2>');
  });

  it('GET /about returns About Page', async () => {
    const res = await request(app).get('/about');
    expect(res.status).to.equal(200);
    expect(res.headers['content-type']).to.match(/html/);
    expect(res.text).to.include('<h2>About Page</h2>');
  });
}); 