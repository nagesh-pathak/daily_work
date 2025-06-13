Business Service 	Feature 	SLI 	SLO	"Active / In Production
(Yes / No)"	Priority	Data Source	Metric Type	Success Metric	Total Metric	Owners	Comments
IAM	Sign-in	Latency	<10 sec	Yes	P1					Mark/Vamsi	Oauth2 user flow latency
	API Requests	API Latency	<200ms	Yes	P1					Mark/Vamsi	Non-bulk APIs
		API Availability	99.99	No	P1					Mark/Vamsi	Non 500 responses, timeouts
	AuthZ	Permission Propagation Delay	<10 min	No	P2					Mark/Vamsi	
	Entitlements	Entitlement Propagation Delay	<20 min	No	P2					Mark/Vamsi	time to propagte group changes or roles changes to enforcement of those in RBAC decisions
Logs	Security	API Latency (1 day)	<10 sec	No	P2					Mark/Vamsi	
		API Latency (7 days)	<15 sec	No	P2					Mark/Vamsi	
		API Latency (30 days)	<45 sec	No	P2					Mark/Vamsi	
		API Availability	99.95	No	P2					Mark/Vamsi	
	Service	API Latency (1 day)	<10 sec	Yes	P2					Mark/Vamsi	
		API Latency (7 days)	<15 sec	Yes	P2					Mark/Vamsi	
		API Latency (30 days)	<45 sec	Yes	P2					Mark/Vamsi	
		API Availability	99.95	No	P2					Mark/Vamsi	
	Audit	API Latency (1 day)	<10 sec	Yes	P2					Mark/Vamsi	
		API Latency (7 days)	<15 sec	Yes	P2					Mark/Vamsi	
		API Latency (30 days)	<45 sec	Yes	P2					Mark/Vamsi	
		API Availability	99.95	No	P2					Mark/Vamsi	
	Customer Metrics	API Latency	< 3 sec	No	P2					Mark/Vamsi	
		API Availability	99.95	No	P2					Mark/Vamsi	
Notification	Notifications	Notifications list API Latency	<3 sec	No	P2					Mark/Vamsi	
		API Availability	99.95	No	P2					Mark/Vamsi	
		Time to Notify - low priority	<10 min	No	P2					Mark/Vamsi	Time to availability as toas message in UI
		Time to Notify - medium priority	<5 min	No	P2					Mark/Vamsi	
		Time to Notify - high priority	<1 min	No	P2					Mark/Vamsi	
Import/Export	Import/Export	API Latency	Variable by application	N/A	P3					Mark/Vamsi	
		API Availability	99.95	No	P3					Mark/Vamsi	
		API Availability	99.99	No	P3					Mark/Vamsi	
Provisioning	Provisioning	Time to Provision	<5 min	No	P2					Mark/Vamsi	
Global Search	Global Search	API Latency (0-100K objects)	< 5 sec	Yes	P3					Mark/Vamsi	
		API Latency (100K-500K objects)	< 7 sec	Yes	P3					Mark/Vamsi	
		API Latency (500K-1M objects)	< 10 sec	Yes	P3					Mark/Vamsi	
		API Latency (>1M objects)	< 20 sec	Yes	P3					Mark/Vamsi	
		API Availability	99.95	No	P2					Mark/Vamsi	
		Search Propagation Delay	< 1 min	No	P3					Mark/Vamsi	
Tagging	Tagging	Tagging List API Latency	< 3 sec	Yes	P2					Mark/Vamsi	
		API Availability	99.99	No	P2					Mark/Vamsi	
		Tag Creation Latency	< 30 sec	Yes	P2					Mark/Vamsi	Time to availability as toast message in UI
		Tag Update Latency	< 30 sec	Yes	P2					Mark/Vamsi	
		Tag Delete Latency	< 30 sec	Yes	P2					Mark/Vamsi	
Entitlements	Entitlements	Config bundle update	<15 min	No	P1					Mark/Vamsi	