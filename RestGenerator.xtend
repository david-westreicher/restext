/*
 * generated by Xtext
 */
package at.westreicher.rest.generator

import at.westreicher.rest.rest.Command
import at.westreicher.rest.rest.Ressource
import java.util.List
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator

import static extension org.eclipse.xtext.EcoreUtil2.*
import at.westreicher.rest.rest.Entity
import at.westreicher.rest.rest.Type

/**
 * Generates code from your model files on save.
 * 
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#code-generation
 */
class RestGenerator implements IGenerator {

	override void doGenerate(Resource resource, IFileSystemAccess fsa) {
		fsa.generateFile('package.json', getPackageJson(resource.normalizedURI.lastSegment.replace('.rest', '')))
		val ressources = resource.allContents.filter(typeof(Ressource)).toList
		val entities = resource.allContents.filter(typeof(Entity)).toList
		fsa.generateFile('server.js', getServer(ressources))
		for (Ressource r : ressources)
			fsa.generateFile('ressources/' + r.name + '.js', getRessource(r))
		for (Entity e : entities)
			fsa.generateFile('validation/' + e.name + '.js', getValidation(e))
	}

	def getValidation(Entity entity) {
		'''
			var Joi = require('joi');
			var schema = Joi.object().keys({
				id: Joi.number().integer(),
				«FOR p : entity.props»
					«p.name»: Joi.«typeToJoi(p.type)»,
				«ENDFOR»
			});
			function validate(obj){
				var result = Joi.validate(obj,schema);
				if(result.error===null){
					console.log('valid');
					return true;
				}else{
					console.log('not valid');
					console.log(result.error);
					return false;
				}
			}
			module.exports = validate;
		'''
	}

	def typeToJoi(Type t) {
		switch (t) {
			case BOOLEAN:
				return 'boolean()'
			case STRING:
				return 'string()'
			case INTEGER:
				return 'number().integer()'
		}
	}

	def getRessource(Ressource r) {
		'''
			var express = require('express');
			var validate = require('../validation/«r.entity.name»');
			
			function cors(res){
			    res.setHeader('Access-Control-Allow-Origin', 'http://localhost:8000');
			    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, PATCH, DELETE, CLICK');
			    res.setHeader('Access-Control-Allow-Headers', 'X-HTTP-Method-Override,X-Requested-With,content-type');
			    res.setHeader('Access-Control-Allow-Credentials', true);
			}
			
			var router = express.Router();
			var dbarr = [];
			var name = '«r.entity.name»';
			
			function getIndex(id){
			    var index = -1;
			    for(var i=0;i<dbarr.length;i++){
			        if(dbarr[i].id == id){
			            index = i;
			            break;
			        }
			    }
			    return index;
			}
			«IF r.commands.contains(Command.READ)»
				router.get('/', function(req, res, next) {
				    console.log('list all '+name+'s');
				    cors(res);
				    res.json(dbarr);
				});
				router.get('/:id', function(req, res, next) {
					var id = req.param('id');
					   console.log('getting '+name,id);
					   var index = getIndex(id);
					   cors(res);
					   if(index>=0){
					   	console.log('success');
					   	   res.json(dbarr[index]);
					   }else{
					   	var errText = 'Couldn\'t find '+name+' with id '+id;
					   	console.log(errText);
					   	res.status(400).send({ error: errText});
					   }
				});
			«ENDIF»
			«IF r.commands.contains(Command.CREATE)»
				router.post('/', function(req, res, next) {
				    var entity = req.body;
				    entity.id = Date.now();
				    console.log('create '+name,entity);
				    cors(res);
				    if(validate(entity)){
				     dbarr.push(entity);
				     console.log('success');
				     res.status(201).json(entity);
				}else{
				    console.log('not valid');
				    res.status(400).json({ error: 'not a valid '+name,entity:entity});
				}
				});
			«ENDIF»
			«IF r.commands.contains(Command.UPDATE)»
				router.put('/:id', function(req, res, next) {
					var id = req.param('id');
					   var entity = req.body;
					   console.log('update '+name,id,'with',entity);
					   var index = getIndex(entity.id);
					cors(res);
					var errText = null;
					if(!validate(entity)){
						errText = 'not a valid '+name;
					}else if(entity.id!=id){
						errText = 'id of request ('+id+') didn\'t match payloadid ('+entity.id+')';
					}else if(index<0){
						errText = 'Couldn\'t find '+name+' with id '+id;
						  }
						  if(errText==null){
						   dbarr[index] = entity;
						   console.log('success');
						   res.json(entity);
						  }else{
						  	console.log(errText);
						  	res.status(400).send({ error: errText});
						  }
				});
			«ENDIF»
			«IF r.commands.contains(Command.DELETE)»
				router.delete('/:id', function(req, res, next) {
					var id = req.param('id');
					   console.log('delete '+name,id);
					   var index = getIndex(id);
					   cors(res);
					   if(index>=0){
					       dbarr.splice(index,1);
					   	console.log('success');
					   	   res.json(null);
					   }else{
					   	var errText = 'Couldn\'t find '+name+' with id '+id;
					   	console.log(errText);
					   	res.status(400).send({ error: errText});
					   }
				});
			«ENDIF»
			router.options('/:id', function(req, res, next) {
			    cors(res);
			    res.json(null);
			});
			router.options('/', function(req, res, next) {
			    cors(res);
			    res.json(null);
			});
			
			module.exports = router;
		'''
	}

	def getServer(List<Ressource> ress) {
		'''
			var express = require('express');
			var bodyParser = require('body-parser');
			
			var app = express();
			app.use(bodyParser.json());
			app.use(bodyParser.urlencoded({ extended: false }));
			«FOR r : ress»
				console.log('Adding ressource «r.path»');
				app.use('«r.path»',require('./ressources/«r.name»'));
			«ENDFOR»
			console.log('Starting REST server on localhost:8080');
			app.listen(8080);
			
			module.exports = app;
		'''
	}

	def getPackageJson(String name) {
		'''
			{
			  "name": "«name»",
			  "version": "0.0.0",
			  "private": true,
			  "dependencies": {
			    "body-parser": "~1.8.1",
			    "joi": "~6.4.2",
			    "express": "~4.9.0"
			  }
			}
		'''
	}
}
