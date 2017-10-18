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
          //console.log(r.body);
          r.body.me.email.should.equal('alice@email.com');
          r.body.me.role.should.equal('webuser');
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
          //console.log(r.body);
          r.body.email.should.equal('alice@email.com');
          r.body.role.should.equal('webuser');
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
          r.body.me.role.should.equal('webuser');
        })
    });
    it('signup with email as doctor', function(done) {
      rest_service()
        .post('/rpc/signup')
        .set('Accept', 'application/vnd.pgrst.object+json')
        .send({
          email:"jacob@email.com",
          password: "pass",
          role: "doctor"
        })
        .expect('Content-Type', /json/)
        .expect(200, done)
        .expect( r => {
          //console.log(r.body);
          r.body.me.email.should.equal('jacob@email.com');
          r.body.me.role.should.equal('doctor');
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

    it('refuse signup with unknown role', function(done) {
      rest_service()
        .post('/rpc/signup')
        .set('Accept', 'application/vnd.pgrst.object+json')
        .send({
          email: "janice@email.com",
          password: "pass",
          role: "dr"
        })
        .expect('Content-Type',/json/)
        .expect(400, done)
        .expect(r => {
          //console.log(r.body);
          r.body.message.should.equal('invalid input value for enum user_role: "dr"');
        })
    });

    it('refuse signup with missing email', function(done) {
      rest_service()
      .post('/rpc/signup')
      .set('Accept', 'application/vnd.pgrst.object+json')
      .send({
        email: " ",
        password: "pass"
      })
      .expect('Content-Type',/json/)
      .expect(400, done)
      .expect(r => {
        //console.log(r.body);
        r.body.message.should.equal('new row for relation "user" violates check constraint "user_email_check"');
      })
    });

    it('refuse signup with missing password', function(done) {
      rest_service()
      .post('/rpc/signup')
      .set('Accept', 'application/vnd.pgrst.object+json')
      .send({
        email: "badri@email.com",
        password: " "
      })
      .expect('Content-Type',/json/)
      .expect(403, done)
      .expect(r => {
        //console.log(r.body);
        r.body.message.should.equal('invalid password');
      })
    });

  });
  

});