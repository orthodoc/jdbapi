import {rest_service, jwt, resetdb} from '../common.js';
const request = require('supertest');
const should = require("should");

describe('auth', function() {
  before(function(done){ resetdb(); done(); });
  
  describe('login with email', function() {
    it('login', function(done) {
      rest_service()
        .post('/rpc/login?select=me,token')
        .set('Accept', 'application/vnd.pgrst.object+json')
        .send({ 
          email:"alice@email.com",
          password: "pass"
        })
        .expect('Content-Type', /json/)
        .expect(200, done)
        .expect( r => {
          //console.log(r.body)
          r.body.me.email.should.equal('alice@email.com');
        })
    });
  
    it('me', function(done) {
      rest_service()
        .post('/rpc/me')
        .set('Accept', 'application/vnd.pgrst.object+json')
        .set('Authorization', 'Bearer ' + jwt)
        .send({})
        .expect('Content-Type', /json/)
        .expect(200, done)
        .expect( r => {
          //console.log(r.body)
          r.body.email.should.equal('alice@email.com');
        })
    });
  });

  describe('login with phone number', function() {
    it('login', function(done) {
      rest_service()
        .post('/rpc/login?select=me,token')
        .set('Accept', 'application/vnd.pgrst.object+json')
        .send({
          phone_number: "+96872343234"
        })
        .expect('Content-Type', /json/)
        .expect(200, done)
        .expect(r => {
          r.body.me.phone_number.should.equal('+96872343234');
        })
    });
    it('me', function(done) {
      rest_service()
        .post('/rpc/me')
        .set('Accept', 'application/vnd.pgrst.object+json')
        .set('Authorization', 'Bearer ' + jwt)
        .send({})
        .expect('Content-Type',/json/)
        .expect(200, done)
        .expect(r => {
          r.body.phone_number.should.equal('+96872343234');
        })
    });
  });

  describe('token', function() {
    it('refresh_token', function(done) {
      rest_service()
        .post('/rpc/refresh_token')
        .set('Accept', 'application/vnd.pgrst.object+json')
        .set('Authorization', 'Bearer ' + jwt)
        .send({})
        .expect('Content-Type', /json/)
        .expect(200, done)
        .expect( r => {
          //console.log(r.body)
          r.body.length.should.above(0);
        })
    });
  });

  describe('signup', function() {
    it('signup with email', function(done) {
      rest_service()
        .post('/rpc/signup')
        .set('Accept', 'application/vnd.pgrst.object+json')
        .send({
          email:"john@email.com",
          password: "pass"
        })
        .expect('Content-Type', /json/)
        .expect(200, done)
        .expect( r => {
          //console.log(r.body);
          r.body.me.email.should.equal('john@email.com');
        })
    });
    it('signup with phone number', function(done) {
      rest_service()
      .post('/rpc/signup')
      .set('Accept', 'application/vnd.pgrst.object+json')
      .send({
        phone_number: "+96873467878"
      })
      .expect('Content-Type',/json/)
      .expect(200, done)
      .expect(r => {
        r.body.me.phone_number.should.equal('+96873467878');
      })
    });
    it('signup with email and phone number', function(done) {
      rest_service()
        .post('/rpc/signup')
        .set('Accept', 'application/vnd.pgrst.object+json')
        .send({
          email: 'bdb@email.com',
          password: 'pass',
          phone_number: "+96836354676"
        })
        .expect('Content-Type',/json/)
        .expect(200, done)
        .expect(r => {
          //console.log(r.body);
          r.body.me.email.should.equal('bdb@email.com');
          r.body.me.phone_number.should.equal('+96836354676');
        })
    });
  });

  describe('without credentials', function () {
    it('refuse login with missing email', function(done) {
      rest_service()
        .post('/rpc/login?select=me,token')
        .set('Accept', 'application/vnd.pgrst.object+json')
        .send({
          email: "",
          password: ""
        })
        .expect('Content-Type',/json/)
        .expect(400, done)
        .expect(r => {
          //console.log(r.body);
          r.body.message.should.equal('invalid email/password or phone number');
        })
    });

    it('refuse login with missing phone number', function(done) {
      rest_service()
      .post('/rpc/login?select=me,token')
      .set('Accept', 'application/vnd.pgrst.object+json')
      .send({
        phone_number: ""
      })
      .expect('Content-Type',/json/)
      .expect(400, done)
      .expect(r => {
        //console.log(r.body);
        r.body.message.should.equal('invalid email/password or phone number');
      })
    });

    it('refuse signup with missing phone number', function(done) {
      rest_service()
      .post('/rpc/login?select=me,token')
      .set('Accept', 'application/vnd.pgrst.object+json')
      .send({
        phone_number: ""
      })
      .expect('Content-Type',/json/)
      .expect(400, done)
      .expect(r => {
        //console.log(r.body);
        r.body.message.should.equal('invalid email/password or phone number');
      })
    });

    it('refuse signup with missing email and password', function(done) {
      rest_service()
      .post('/rpc/login?select=me,token')
      .set('Accept', 'application/vnd.pgrst.object+json')
      .send({
        email: "",
        password: ""
      })
      .expect('Content-Type',/json/)
      .expect(400, done)
      .expect(r => {
        //console.log(r.body);
        r.body.message.should.equal('invalid email/password or phone number');
      })
    });

  });
  

});