# Giving the Credits where it's due
First let me give the credit to my fellow RedHatter who is the original source of this demo: https://github.com/rcarrata/istio-files
I have improved/change this based on what I need and this is the outcome.


# Draft Instruction

## Pre-reqs (if you run the lab already):

export OCP_NS=servicemesh-demo
export Pdemo=anz-servicemesh-demo
oc new-project $OCP_NS

Delete ServiceMeshMemberRoll

# Tasks 1: Deploy Microservices 

The Microservices application will look like this.
( customer | partner ) ⇒ preference ⇒ recommendation

*Deploy Customer Application v1 app*

> oc new-app -l app=customer,version=v1 --name=customer --docker-image=quay.io/mikecali/customer -e VERSION=v1 -e  JAVA_OPTIONS='-Xms512m -Xmx512m -Djava.net.preferIPv4Stack=true' -n $Pdemo 

> oc expose svc customer -n $Pdemo 

*Deploy Partner v1 app*

> oc new-app -l app=partner,version=v1 --name=partner --docker-image=quay.io/mikecali/partner:java1 -e JAVA_OPTIONS='-Xms512m -Xmx512m -Djava.net.preferIPv4Stack=true' -n $Pdemo

> oc expose svc partner -n $Pdemo 

*Deploy Preference v1 App*

> oc new-app -l app=preference,version=v1 --name=preference --docker-image=quay.io/mikecali/preference -e JAVA_OPTIONS='-Xms512m -Xmx512m -Djava.net.preferIPv4Stack=true'  -n $Pdemo 

*Deploy recommendation v1 App*

> oc new-app -l app=recommendation,version=v1 --name=recommendation --docker-image=quay.io/mikecali/recommendations -e JAVA_OPTIONS='-Xms512m -Xmx512m -Djava.net.preferIPv4Stack=true' -e VERSION=v1 -n $Pdemo 


*Check/verify routes:*

> oc get route | egrep -i 'customer|partner'


*Access Routes:* 

> curl -I (partner.routes)

This time, what we have just done is to deploy applications using the traditional App Deployment.

# Task 2: Now lets go and the Meshing!!
First let's understand the difference between upstream Istio Sidecar injector and the RH Servicemesh Maestra release.

Istio: -  sidecar injector injects all deployments within labeled projects
Maestra: - relies on presence of the sidecar.istio.io/inject annotation and the project being listed in the ServiceMeshMemberRoll.

sidecar.istio.io/inject: true

First, we need to enble sidecar enjection of Maestra Proxy the the pods we created. we need to add annotation in the controllers like DC and Deployments and others.
Let's inspect a couple of dc that we use in the running services first.

Run:
oc describe dc/customer -n $Pdemo | grep Annotations -A3
End:

Before we add the annotation that we just discuss, let me configure the Servicemeshroll by adding the namespace where the services run...

run:
oc edit ServiceMeshMemberRoll -n istio-system

Run:
oc get ServiceMeshMemberRoll -n istio-system -o yaml | grep spec -A3
end:

Let's us patch this with a new annotation.

Run this:
oc patch dc/customer -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}' -n $Pdemo 
oc patch dc/preference -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}' -n $Pdemo 
oc patch dc/recommendation -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}' -n $Pdemo 
oc patch dc/partner -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}' -n $Pdemo 
End:


Then we verify if the annotations is added to the DC's

Run:
oc describe dc/partner -n $Pdemo | grep Annotations -A3 
End:

Now it is time to manage the ingress traffic to our application via ServiceMesh - Remember even though we already added the services to servicemesh via ServiceMeshMemberRoll - 
servicemesh controllers still is not aware of the services


In Openshift, when a oc new-app is used, several kubernetes resources are created within this command. One of this services is the SVC resources (Service).
Let's checkout the service of the customer microservice deployed


oc get svc/customer -n $Pdemo -o json | jq -r '[.spec.selector]' :

In here, we see that  kubernetes services match with pods based on the selector we have defined on it. Example the app, deploymentconfig, and version labels define the match with this pods. 
Now we need to update the application to the new selector.

cat customer/kubernetes/Service.yml | grep selector -A5 :

This selector will match any pod with the labelled with app- customer", and this possibility includes several versions of the same application.
To make the change, we need to delete the services that we inherited from the initial deployment.

Run this:
oc delete svc/customer -n $Pdemo 
oc delete svc/preference -n $Pdemo 
oc delete svc/recommendation -n $Pdemo 
oc delete svc/partner -n $Pdemo 
End:

Let's make sure the DC has the annotions needed
Run:
oc describe dc/partner -n $Pdemo | grep Annotations -A3
end:

Run this again: If Sidecar is missing
oc patch dc/customer -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}' -n $Pdemo 
oc patch dc/preference -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}' -n $Pdemo 
oc patch dc/recommendation -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}' -n $Pdemo 
oc patch dc/partner -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}' -n $Pdemo 
End:

Now we need to apply the new selector

Run this:
oc apply -f customer/kubernetes/Service.yml -n $Pdemo
oc apply -f preference/kubernetes/Service.yml -n $Pdemo
oc apply -f recommendation/kubernetes/Service.yml -n $Pdemo
oc apply -f partner/kubernetes/Service.yml -n $Pdemo
End:


Now that we have the right labels on all the Microservices - we now need to add the Sevice Mesh Components

Virtual Service:  lets you configure how requests are routed to a service within an Istio service mesh
Destination Rule: are applied after virtual service routing rules are evaluated, so they apply to the traffic’s “real” destination.
Gateway: You use Gateways to manage inbound and outbound traffic for your mesh, letting you specify which traffic you want to enter or leave the mesh.


Render and Apply the objects to enable Ingress Routing to CUSTOMER app:
Run this:
export APP_SUBDOMAIN=$(oc get route -n istio-system | grep -i kiali | awk '{ print $2 }' | cut -f 2- -d '.')
echo $APP_SUBDOMAIN

cat customer-ingress_mtls.yml | NAMESPACE=$(echo $Pdemo) envsubst | oc apply -f -
End:

Let's check if we can access the application now and then we will check KIALI and Jaeger

Run:
oc get route -n istio-system customer
End:

Let's dive into Ingress Routing objects:

Start:
oc get virtualservice -n $Pdemo customer -o yaml
End:

VirtualService: The virtualservice uses points to the gateway of customer-gw, and sets the route request to the subset of the host of customer host and with the subset of version-v1.

Start:
oc get destinationrule -n $Pdemo customer -o yaml
end:

Destinationrule: the destination rule sets the subset of versions (actually version-v1 but in the next labs will be expanding) 
that we have in place. Also the host that belongs this destinationrule, 

And an important feature - enabled the Mutual TLS.


Let's now access the Customer microservice app - and view in Kiali:


oc get route -n istio-system customer
curl -I

Let's verify the Mutual TLS is running.

run:
openssl s_client -connect customer-anz-servicemesh-demo-istio-system.apps.cluster-e890.e890.sandbox1543.opentlc.com:443
end:

Lets verify the old route if we can still access it now that ingress traffic is managed by ServiceMesh:

oc get route -n $Pdemo customer
curl -I

===

NOW lets expose Partner App to use ServiceMesh

Render and Apply the objects to enable Ingress Routing to CUSTOMER app.
Run This:
cat partner-ingress_mtls.yml | NAMESPACE=$(echo $Pdemo) envsubst | oc apply -f -
End:

Now let us verify if we now have 2 ingress routing in a single service mesh Control Plane
Run:
oc get routes -n istio-system | egrep "customer|partner"
End:

======================================
BlueGreen Deployments:
A Blue/Green deployment will allow you to define two (or more) versions of the same application to receive traffic with zero downtime. 
This approach, for instance, will let you release a new version and gradually increment the amount of traffic this version receives.

Run:
export APP_SUBDOMAIN=$(oc get route -n istio-system | grep -i kiali | awk '{ print $2 }' | cut -f 2- -d '.')
echo $APP_SUBDOMAIN
end:


Deploy Recommendation App v2
Run:
oc new-app -l app=recommendation,version=v2 --name=recommendation-v2 --docker-image=quay.io/rcarrata/recommendation:vertx -e JAVA_OPTIONS='-Xms512m -Xmx512m -Djava.net.preferIPv4Stack=true' -e VERSION=v2 -n $Pdemo
oc delete svc/recommendation-v2 -n $OCP_NS
oc get pods -n $OCP_NS | grep recommendation-v2

End:

Then Inject the sidecar to the updated dc/recommendation

Run:
oc patch dc/recommendation-v2 -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}' -n $OCP_NS
End:

Once the patch is done we can execute some test either using customer or partner services.

Run:
oc get routes -n istio-system | egrep "customer|partner"
End:

Show 50-50 weight routes
Run:
cat recommendation-v1_v2_mtls.yml
End:

Apply 75-50 weight routes
Run:
oc apply -f recommendation-v1_v2_25_75.mtls.yml
End:

Test and view in Kiali


========================================
Traffic Mirroring:
Traffic mirroring, also called shadowing, is a powerful concept that allows feature teams to bring changes to production with as little risk as possible. 
Mirroring sends a copy of live traffic to a mirrored service. The mirrored traffic happens out of band of the critical request path for the primary service.

run:
export APP_SUBDOMAIN=$(oc get route -n istio-system | grep -i kiali | awk '{ print $2 }' | cut -f 2- -d '.')
echo $OCP_SUBDOMAIN
end:

Before we create need to create customer app v2 first.

run:
oc new-app -l app=customer,version=v2 --name=customer-v2 --docker-image=quay.io/rcarrata/customer:quarkus -e VERSION=v2 -e  JAVA_OPTIONS='-Xms512m -Xmx512m -Djava.net.preferIPv4Stack=true' -n $OCP_NS
oc delete svc/customer-v2 -n $OCP_NS
oc patch dc/customer-v2 -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}' -n $OCP_NS
end:

Now lets render and apply the mirror VirtualService
run:
cat customer-mirror-traffic.yml | envsubst | oc apply -f -
end:

So in conclusion, this route rule sends 100% of the traffic to v1. The last stanza specifies that you want to mirror to the customer:v2 service. 
When traffic gets mirrored, the requests are sent to the mirrored service with their Host/Authority headers appended with -shadow. For example, cluster-1 becomes cluster-1-shadow.

Also, it is important to note that these requests are mirrored as “fire and forget”, which means that the responses are discarded.

Furthermore, you can use the mirror_percent field to mirror a fraction of the traffic, instead of mirroring all requests. 
If this field is absent, for compatibility with older versions, all traffic will be mirrored


run:
 cat customer-mirror-traffic-adv.yml | envsubst | oc apply -f -
end:
