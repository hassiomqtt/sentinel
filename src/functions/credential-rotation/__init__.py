"""
Credential Rotation Function
Automatically rotates compromised credentials
"""
import azure.functions as func
import logging
import json
import os
from datetime import datetime
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from msgraph import GraphServiceClient
from msgraph.generated.users.item.revoke_sign_in_sessions.revoke_sign_in_sessions_request_builder import RevokeSignInSessionsRequestBuilder

# Initialize logger
logger = logging.getLogger(__name__)

# Configuration
KEY_VAULT_URI = os.environ.get('KEY_VAULT_URI')
THREAT_SCORE_THRESHOLD = int(os.environ.get('THREAT_SCORE_THRESHOLD', '70'))
ENABLE_AUTO_REMEDIATION = os.environ.get('ENABLE_AUTO_REMEDIATION', 'false').lower() == 'true'

# Initialize Azure clients
credential = DefaultAzureCredential()
kv_client = SecretClient(vault_url=KEY_VAULT_URI, credential=credential)
graph_client = GraphServiceClient(credential)


async def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    Main function handler for credential rotation
    """
    logger.info('Credential rotation function triggered')

    try:
        # Parse request body
        req_body = req.get_json()
        
        user_id = req_body.get('userId')
        threat_score = req_body.get('threatScore', 0)
        incident_id = req_body.get('incidentId')
        
        if not user_id:
            return func.HttpResponse(
                json.dumps({"error": "userId is required"}),
                status_code=400,
                mimetype="application/json"
            )

        logger.info(f"Processing credential rotation for user: {user_id}, threat_score: {threat_score}")

        # Check if auto-remediation is enabled and threat score exceeds threshold
        if not ENABLE_AUTO_REMEDIATION:
            logger.info(f"Auto-remediation disabled - dry run mode")
            return func.HttpResponse(
                json.dumps({
                    "status": "dry_run",
                    "message": "Auto-remediation is disabled",
                    "would_execute": threat_score >= THREAT_SCORE_THRESHOLD
                }),
                status_code=200,
                mimetype="application/json"
            )

        if threat_score < THREAT_SCORE_THRESHOLD:
            logger.info(f"Threat score {threat_score} below threshold {THREAT_SCORE_THRESHOLD}")
            return func.HttpResponse(
                json.dumps({
                    "status": "skipped",
                    "reason": "Threat score below threshold",
                    "threat_score": threat_score,
                    "threshold": THREAT_SCORE_THRESHOLD
                }),
                status_code=200,
                mimetype="application/json"
            )

        # Execute remediation steps
        result = await rotate_credentials(user_id, incident_id)
        
        return func.HttpResponse(
            json.dumps(result),
            status_code=200,
            mimetype="application/json"
        )

    except ValueError as e:
        logger.error(f"Invalid request: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": "Invalid request format"}),
            status_code=400,
            mimetype="application/json"
        )
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}", exc_info=True)
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            mimetype="application/json"
        )


async def rotate_credentials(user_id: str, incident_id: str) -> dict:
    """
    Execute credential rotation steps
    
    Steps:
    1. Revoke all active sessions
    2. Force password reset
    3. Rotate service principal credentials (if applicable)
    4. Update Key Vault secrets
    5. Log remediation action
    """
    actions_taken = []
    
    try:
        # Step 1: Revoke all sessions
        logger.info(f"Revoking all sessions for user {user_id}")
        await graph_client.users.by_user_id(user_id).revoke_sign_in_sessions.post()
        actions_taken.append("revoked_sessions")
        
        # Step 2: Force password reset
        logger.info(f"Forcing password reset for user {user_id}")
        request_body = {
            "passwordProfile": {
                "forceChangePasswordNextSignIn": True,
                "forceChangePasswordNextSignInWithMfa": True
            }
        }
        await graph_client.users.by_user_id(user_id).patch(request_body)
        actions_taken.append("forced_password_reset")
        
        # Step 3: Check and rotate service credentials
        secrets = kv_client.list_properties_of_secrets()
        rotated_secrets = []
        
        for secret in secrets:
            # Check if secret is owned by this user
            if secret.tags and secret.tags.get('owner') == user_id:
                logger.info(f"Rotating secret: {secret.name}")
                # Generate new secret value
                new_value = generate_secure_password()
                kv_client.set_secret(secret.name, new_value)
                rotated_secrets.append(secret.name)
        
        if rotated_secrets:
            actions_taken.append(f"rotated_secrets:{len(rotated_secrets)}")
        
        # Step 4: Log to Sentinel
        log_remediation_action(user_id, incident_id, actions_taken)
        
        return {
            "status": "success",
            "user_id": user_id,
            "incident_id": incident_id,
            "actions_taken": actions_taken,
            "timestamp": datetime.utcnow().isoformat(),
            "rotated_secrets_count": len(rotated_secrets)
        }
        
    except Exception as e:
        logger.error(f"Error during credential rotation: {str(e)}", exc_info=True)
        return {
            "status": "failed",
            "user_id": user_id,
            "incident_id": incident_id,
            "actions_taken": actions_taken,
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }


def generate_secure_password() -> str:
    """Generate a cryptographically secure password"""
    import secrets
    import string
    
    alphabet = string.ascii_letters + string.digits + string.punctuation
    password = ''.join(secrets.choice(alphabet) for i in range(32))
    return password


def log_remediation_action(user_id: str, incident_id: str, actions: list):
    """Log remediation action to Sentinel"""
    logger.info(f"Remediation completed for user {user_id}, incident {incident_id}")
    logger.info(f"Actions taken: {', '.join(actions)}")
    # Additional logging to Log Analytics would go here
